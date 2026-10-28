import MediaPlayer
import Observation
import os
import SwiftUI

@Observable
final class GroupedCollection: MediaCollection {
	static let artists = GroupedCollection(groupBy: "artist")
	static let genres = GroupedCollection(groupBy: "genre")

	let groupBy: String

	var unavailable: MPMediaLibraryAuthorizationStatus?
#if targetEnvironment(simulator)
	var entries: [MediaEntry] = GroupedCollection.screenshotData
#else
	var entries: [MediaEntry] = []
#endif
	/// The most 5-star songs any entry has (capped at 99), which bounds the minimum stepper.
	var maximumSongsLimit = LibraryGrouping.minimumSongsCap

	init(groupBy: String) {
		self.groupBy = groupBy

		if self.entries.isEmpty, let cache = groupBy == "genre" ? UserDefaults.standard.cachedGenres : UserDefaults.standard.cachedArtists {
			self.entries = cache
				.map { MediaEntry(id: $0[0] as! String, songs: nil, songCount: $0[1] as! Int, artwork: nil) }
			self.maximumSongsLimit = min(LibraryGrouping.minimumSongsCap, entries.map(\.songCount).max() ?? 0)
		}
	}

	static var screenshotData: [MediaEntry] {
		return [
			MediaEntry(id: "The Album Leaf", songs: nil, songCount: 20, artwork: nil),
			MediaEntry(id: "Beach House", songs: nil, songCount: 50, artwork: nil),
			MediaEntry(id: "Belle & Sebastian", songs: nil, songCount: 51, artwork: nil),
			MediaEntry(id: "Bob Marley & The Wailers", songs: nil, songCount: 33, artwork: nil),
			MediaEntry(id: "CHVRCHΞS", songs: nil, songCount: 23, artwork: nil),
			MediaEntry(id: "The Decemberists", songs: nil, songCount: 52, artwork: nil),
			MediaEntry(id: "Frédéric Chopin", songs: nil, songCount: 22, artwork: nil),
			MediaEntry(id: "indigo la End", songs: nil, songCount: 37, artwork: nil),
			MediaEntry(id: "Lost Frequencies", songs: nil, songCount: 23, artwork: nil),
			MediaEntry(id: "The National", songs: nil, songCount: 61, artwork: nil),
			MediaEntry(id: "Polo & Pan", songs: nil, songCount: 16, artwork: nil),
			MediaEntry(id: "Sigur Rós", songs: nil, songCount: 30, artwork: nil),
			MediaEntry(id: "Stromae", songs: nil, songCount: 15, artwork: nil),
			MediaEntry(id: "Sufjan Stevens", songs: nil, songCount: 16, artwork: nil),
			MediaEntry(id: "Toe", songs: nil, songCount: 34, artwork: nil),
			MediaEntry(id: "Yelle", songs: nil, songCount: 26, artwork: nil),
		]
	}

	/// The grouping for the selected tab, or artists while on the Years tab.
	class var current: GroupedCollection {
		UserDefaults.standard.selectedTab == "genres" ? genres : artists
	}

	private class var other: GroupedCollection {
		current === artists ? genres : artists
	}

	/// Rescans the selected tab's grouping (nothing on the Years tab).
	class func updateCurrent(withAnimation animated: Bool) {
		guard UserDefaults.standard.selectedTab != "years" else { return }
		current.scheduleUpdate(withAnimation: animated)
	}

	/// Rescans both groupings, animating the visible one.
	class func updateAll(withAnimation animated: Bool, after delay: Duration = .zero) {
		current.scheduleUpdate(withAnimation: animated, after: delay)
		other.scheduleUpdate(withAnimation: false, after: delay)
	}

	/// Rescans each grouping whose last scan predates the library's latest change.
	class func updateAllIfLibraryChanged(after delay: Duration = .zero) {
		current.updateIfLibraryChanged(after: delay)
		other.updateIfLibraryChanged(after: delay)
	}

	class func setUnavailable(status: MPMediaLibraryAuthorizationStatus) {
		artists.unavailable = status
	}

	private var pendingUpdate: Task<Void, Never>?
	private var generation = 0
	private var scannedLibraryDate: Date?

	/// Starts a rescan, replacing any rescan still waiting on its delay.
	func scheduleUpdate(withAnimation animated: Bool, after delay: Duration = .zero) {
		pendingUpdate?.cancel()
		pendingUpdate = Task {
			if delay > .zero {
				try? await Task.sleep(for: delay)
			}
			guard !Task.isCancelled else { return }
			await update(withAnimation: animated)
		}
	}

	func updateIfLibraryChanged(after delay: Duration = .zero) {
		// The simulator has no music library; a scan would replace the screenshot data
#if !targetEnvironment(simulator)
		guard MPMediaLibrary.default().lastModifiedDate != scannedLibraryDate else { return }
		scheduleUpdate(withAnimation: false, after: delay)
#endif
	}

	private struct Inputs {
		let generation: Int
		let minimum: Int
		let favorites: [String]
		let combined: [[String]]
		let existingIDs: Set<String>
	}

	/// Scans the music library off the main thread, then applies the result on it.
	@concurrent
	nonisolated func update(withAnimation animated: Bool) async {
		let inputs = await MainActor.run {
			self.generation += 1
			self.scannedLibraryDate = MPMediaLibrary.default().lastModifiedDate
			let defaults = UserDefaults.standard
			return Inputs(generation: self.generation, minimum: defaults.minimum, favorites: defaults.favorites(for: groupBy), combined: defaults.combined(for: groupBy), existingIDs: Set(self.entries.map { $0.id.normalized() }))
		}

		guard let songs = MPMediaQuery.songs().items else {
			log.error("Unable to load music")
			return
		}
		let allGroups = LibraryGrouping.group(songs, groupBy: groupBy, combined: inputs.combined)
#if targetEnvironment(simulator)
		// Limits the list to the screenshot artists
		let groups = groupBy == "artist" ? allGroups.filter { inputs.existingIDs.contains($0.name.normalized()) } : allGroups
#else
		let groups = allGroups
#endif
		let (selected, mostSongsLimit) = LibraryGrouping.select(groups, minimum: inputs.minimum, favorites: inputs.favorites)
		let entries = selected.map { group in
			MediaEntry(id: group.name, songs: group.songs, songCount: group.songs.count, artwork: group.songs.first { $0.artwork != nil }?.artwork)
		}

		await MainActor.run {
			// A newer scan started while this one ran, so its result wins
			guard inputs.generation == self.generation else { return }
			if animated {
				withAnimation {
					apply(mostSongsLimit: mostSongsLimit, entries: entries)
				}
			} else {
				apply(mostSongsLimit: mostSongsLimit, entries: entries)
			}
			let cache = entries.map { [$0.id, $0.songCount] }
			if groupBy == "genre" {
				UserDefaults.standard.cachedGenres = cache
			} else {
				UserDefaults.standard.cachedArtists = cache
			}
		}
	}

	// The stored minimum is left alone when it exceeds this library's largest entry, so a small library on one device doesn't lower it on the others
	private func apply(mostSongsLimit: Int, entries: [MediaEntry]) {
		self.maximumSongsLimit = mostSongsLimit
		self.entries = entries
	}
}
