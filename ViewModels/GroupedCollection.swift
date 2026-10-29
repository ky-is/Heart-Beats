import MediaPlayer
import Observation
import os
import SwiftUI

/// The section label for favorited entries, which list first.
nonisolated let FavoritesLabel = "Favorites"

@Observable
final class GroupedCollection {
	static let artists = GroupedCollection(groupBy: "artist")
	static let genres = GroupedCollection(groupBy: "genre")

	let groupBy: String

	var unavailable: MPMediaLibraryAuthorizationStatus?
	private(set) var entries: [MediaEntry]
	/// The entries with favorites first, in their own section when there are any
	private(set) var sections: [ListGroupEntry]
	/// Whether a scan has ever finished, on this launch or a previous one
	private(set) var hasLoaded = true
	/// The most 5-star songs any entry has (capped at 99), which bounds the minimum stepper.
	var maximumSongsLimit = LibraryGrouping.minimumSongsCap

	init(groupBy: String) {
		self.groupBy = groupBy
#if targetEnvironment(simulator)
		let entries = MediaEntry.screenshotData
#else
		let cached = (groupBy == "genre" ? ListCache.genres : ListCache.artists).load()
		hasLoaded = cached != nil
		let entries = cached ?? []
		maximumSongsLimit = min(LibraryGrouping.minimumSongsCap, entries.map(\.songCount).max() ?? 0)
#endif
		self.entries = entries
		sections = Self.sections(for: entries, favorites: UserDefaults.standard.favorites(for: groupBy))
	}

	nonisolated static func sections(for entries: [MediaEntry], favorites: [String]) -> [ListGroupEntry] {
		let favoriteKeys = Set(favorites.map { $0.normalized() })
		var favoriteEntries: [MediaEntry] = []
		var otherEntries: [MediaEntry] = []
		for entry in entries {
			if favoriteKeys.contains(entry.id.normalized()) {
				favoriteEntries.append(entry)
			} else {
				otherEntries.append(entry)
			}
		}
		return favoriteEntries.isEmpty ? [(nil, otherEntries)] : [(FavoritesLabel, favoriteEntries), (nil, otherEntries)]
	}

	/// The grouping for the selected tab, or artists while on the Years tab.
	static var current: GroupedCollection {
		UserDefaults.standard.selectedTab == "genres" ? genres : artists
	}

	private static var other: GroupedCollection {
		current === artists ? genres : artists
	}

	/// Rescans the selected tab's grouping (nothing on the Years tab).
	static func updateCurrent(withAnimation animated: Bool) {
		guard UserDefaults.standard.selectedTab != "years" else { return }
		current.scheduleUpdate(withAnimation: animated)
	}

	/// Rescans both groupings, animating the visible one.
	static func updateAll(withAnimation animated: Bool, after delay: Duration = .zero) {
		current.scheduleUpdate(withAnimation: animated, after: delay)
		other.scheduleUpdate(withAnimation: false, after: delay)
	}

	/// Rescans each grouping whose last scan predates the library's latest change.
	static func updateAllIfLibraryChanged(after delay: Duration = .zero) {
		current.updateIfLibraryChanged(after: delay)
		other.updateIfLibraryChanged(after: delay)
	}

	/// Drops the cached groupings under memory pressure; the next scan groups again.
	static func releaseMemory() {
		artists.grouped = nil
		genres.grouped = nil
	}

	static func setUnavailable(status: MPMediaLibraryAuthorizationStatus) {
		artists.unavailable = status
	}

	nonisolated struct Inputs: Equatable, Sendable {
		let groupBy: String
		let minimum: Int
		let favorites: [String]
		let combined: [[String]]
		/// Only used in the simulator, to limit the list to the screenshot artists
		let existingIDs: Set<String>
	}

	@ObservationIgnored private var latestScan = LatestScan()
	/// What the shown entries were built from, so a scan with nothing new to read is skipped
	@ObservationIgnored private var scanned: (modifiedDate: Date, inputs: Inputs)?
	/// Grouping only depends on the library and combinations, so a new minimum or favorite only filters it again
	@ObservationIgnored private var grouped: Grouped?
	/// The library version the latest scheduled scan will read, so a "library changed?" check doesn't restart a scan that's already on its way
	@ObservationIgnored private var requestedModifiedDate: Date?

	nonisolated struct Grouped: @unchecked Sendable {
		let modifiedDate: Date
		let combined: [[String]]
		let groups: [LibraryGrouping.Group<MPMediaItem>]
	}

	/// Starts a rescan, replacing any rescan still waiting or running. Skipped when the library and settings are unchanged since the last one.
	func scheduleUpdate(withAnimation animated: Bool, after delay: Duration = .zero) {
		requestedModifiedDate = MusicLibrary.modifiedDate
		latestScan.start(after: delay) { [self] in
			await update(withAnimation: animated)
		}
	}

	func updateIfLibraryChanged(after delay: Duration = .zero) {
		// The simulator has no music library; a scan would replace the screenshot data
#if !targetEnvironment(simulator)
		let modifiedDate = MusicLibrary.modifiedDate
		guard modifiedDate != scanned?.modifiedDate, modifiedDate != requestedModifiedDate else { return }
		scheduleUpdate(withAnimation: false, after: delay)
#endif
	}

	private var currentInputs: Inputs {
		let defaults = UserDefaults.standard
#if targetEnvironment(simulator)
		let existingIDs = Set(entries.map { $0.id.normalized() })
#else
		let existingIDs: Set<String> = []
#endif
		return Inputs(groupBy: groupBy, minimum: defaults.minimum, favorites: defaults.favorites(for: groupBy), combined: defaults.combined(for: groupBy), existingIDs: existingIDs)
	}

	private func update(withAnimation animated: Bool) async {
		let inputs = currentInputs
		if let scanned, scanned.inputs == inputs, scanned.modifiedDate == MusicLibrary.modifiedDate {
			return
		}
		guard let songs = await MusicLibrary.songs() else {
			// Lets the next check try again
			requestedModifiedDate = nil
			return
		}
		let reusable = grouped.flatMap { $0.modifiedDate == songs.modifiedDate && $0.combined == inputs.combined ? $0 : nil }
		let (selected, mostSongsLimit, grouped) = await Self.select(songs, inputs: inputs, grouped: reusable)
		let built = await MediaPlayerQueue.run {
			Self.entries(for: selected.value, favorites: inputs.favorites)
		}
		let (entries, sections) = (built.entries, built.sections)
		// A newer scan replaced this one while it ran, so its result wins
		guard !Task.isCancelled else { return }

		scanned = (songs.modifiedDate, inputs)
		self.grouped = grouped
		let applying = signposter.beginInterval("Apply list", id: signposter.makeSignpostID(), "\(self.groupBy, privacy: .public)")
		defer { signposter.endInterval("Apply list", applying) }
		// The stored minimum is left alone when it exceeds this library's largest entry, so a small library on one device doesn't lower it on the others
		withAnimation(animated ? .default : nil) {
			maximumSongsLimit = mostSongsLimit
			self.entries = entries
			self.sections = sections
			hasLoaded = true
		}
		(groupBy == "genre" ? ListCache.genres : ListCache.artists).save(entries)
	}

	/// Groups the library's 5-star songs and keeps those the list shows, reusing an earlier grouping of the same library and combinations. Only reads song details, so it runs on any background thread.
	@concurrent
	private nonisolated static func select(_ songs: LibrarySongs, inputs: Inputs, grouped: Grouped?) async -> (selected: MediaPlayerValue<[LibraryGrouping.Group<MPMediaItem>]>, mostSongsLimit: Int, grouped: Grouped) {
		let scanning = signposter.beginInterval("Group list", id: signposter.makeSignpostID(), "\(inputs.groupBy, privacy: .public), regroup: \(grouped == nil)")
		defer { signposter.endInterval("Group list", scanning) }
		let grouped = grouped ?? Grouped(modifiedDate: songs.modifiedDate, combined: inputs.combined, groups: LibraryGrouping.group(songs.details, groupBy: inputs.groupBy, combined: inputs.combined).map { LibraryGrouping.Group(name: $0.name, songs: songs.items(for: $0.songs)) })
		let allGroups = grouped.groups
#if targetEnvironment(simulator)
		let groups = inputs.groupBy == "artist" ? allGroups.filter { inputs.existingIDs.contains($0.name.normalized()) } : allGroups
#else
		let groups = allGroups
#endif
		let (selected, mostSongsLimit) = LibraryGrouping.select(groups, minimum: inputs.minimum, favorites: inputs.favorites)
		return (MediaPlayerValue(value: selected), mostSongsLimit, grouped)
	}

	/// Builds the list's entries. Runs on the MediaPlayer queue, since it looks up each entry's artwork; visible rows decode their own covers as soon as they appear.
	private nonisolated static func entries(for selected: [LibraryGrouping.Group<MPMediaItem>], favorites: [String]) -> (entries: [MediaEntry], sections: [ListGroupEntry]) {
		signposter.withIntervalSignpost("Build list entries", id: signposter.makeSignpostID()) {
			let entries = selected.map { MediaEntry(id: $0.name, songs: $0.songs) }
			return (entries, sections(for: entries, favorites: favorites))
		}
	}
}
