import AppIntents
import CoreSpotlight
import Foundation
import MediaPlayer
import os
import UIKit
import WidgetKit

/// How often each artist, genre and year was played from Heart Beats, kept on this device.
nonisolated struct PlayRecord: Codable, Equatable, Sendable {
	var name: String
	var count: Int
	var lastPlayed: Date
}

enum PlayHistory {
	private static let key = "playHistory"

	/// Every kind's records, keyed by kind, then by normalized name
	private static var all: [String: [String: PlayRecord]] {
		get {
			guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
			return (try? JSONDecoder().decode([String: [String: PlayRecord]].self, from: data)) ?? [:]
		}
		set {
			guard let data = try? JSONEncoder().encode(newValue) else { return }
			UserDefaults.standard.set(data, forKey: key)
		}
	}

	static func records(for kind: PlayKind) -> [String: PlayRecord] {
		all[kind.rawValue] ?? [:]
	}

	/// Counts a play, then refreshes the widget.
	static func record(_ name: String, kind: PlayKind, at date: Date = .now) {
		var all = all
		let key = name.normalized()
		var records = all[kind.rawValue] ?? [:]
		var record = records[key] ?? PlayRecord(name: name, count: 0, lastPlayed: date)
		record.name = name
		record.count += 1
		record.lastPlayed = date
		records[key] = record
		all[kind.rawValue] = records
		self.all = all
		TopPlaysWriter.scheduleUpdate()
	}
}

/// Keeps the widget's top artists, genres and years, favorites and list names current: after each play and each scan. Siri, Shortcuts, Spotlight and the control read them too.
enum TopPlaysWriter {
	private static var latest = LatestScan()

	/// Covers are drawn at most about 96 pt wide in the widget
	private static let coverSize: CGFloat = 288

	/// Delayed so a burst of scans and plays writes once.
	static func scheduleUpdate() {
		latest.start(after: .seconds(1)) {
			await update()
		}
	}

	/// The entries the widget shows: most played in Music first, then most played from Heart Beats (then most recent), then list order.
	nonisolated static func ranked(_ entries: [MediaEntry], records: [String: PlayRecord], playCounts: [String: Int]) -> [MediaEntry] {
		let keyed = entries.enumerated().map { index, entry in
			let key = entry.id.normalized()
			return (entry: entry, index: index, musicPlays: playCounts[key] ?? 0, record: records[key])
		}
		return keyed.sorted { lhs, rhs in
			if lhs.musicPlays != rhs.musicPlays {
				return lhs.musicPlays > rhs.musicPlays
			}
			let lhsPlays = lhs.record?.count ?? 0
			let rhsPlays = rhs.record?.count ?? 0
			if lhsPlays != rhsPlays {
				return lhsPlays > rhsPlays
			}
			let lhsLast = lhs.record?.lastPlayed ?? .distantPast
			let rhsLast = rhs.record?.lastPlayed ?? .distantPast
			return lhsLast != rhsLast ? lhsLast > rhsLast : lhs.index < rhs.index
		}
			.map(\.entry)
	}

	/// Music's play counts for each kind's entries, from the shared library read.
	@concurrent
	private nonisolated static func playCounts(_ songs: LibrarySongs, combinedArtists: [[String]], combinedGenres: [[String]]) async -> [PlayKind: [String: Int]] {
		[
			.artist: LibraryGrouping.playCounts(songs.details, groupBy: "artist", combined: combinedArtists),
			.genre: LibraryGrouping.playCounts(songs.details, groupBy: "genre", combined: combinedGenres),
			.year: LibraryGrouping.yearPlayCounts(songs.details, calendar: .current),
		]
	}

	static func listEntries(for kind: PlayKind) -> [MediaEntry] {
		switch kind {
		case .artist: GroupedCollection.artists.sections.flatMap(\.entries)
		case .genre: GroupedCollection.genres.sections.flatMap(\.entries)
		case .year: YearsCollection.shared.entries
		}
	}

	private static func update() async {
		guard let coversURL = TopPlays.coversURL else {
			log.error("No app group container for the widget")
			return
		}
		try? FileManager.default.createDirectory(at: coversURL, withIntermediateDirectories: true)
		var topPlays = TopPlays.load() ?? TopPlays()
		let defaults = UserDefaults.standard
		var playCounts: [PlayKind: [String: Int]] = [:]
		if !SampleLibrary.isOn, let songs = await MusicLibrary.songs() {
			playCounts = await Self.playCounts(songs, combinedArtists: defaults.combined(for: "artist"), combinedGenres: defaults.combined(for: "genre"))
		}
		for kind in PlayKind.allCases {
			let entries = listEntries(for: kind)
			// Cached placeholders have no songs or covers yet, so the last written entries stay until a scan finishes
			guard SampleLibrary.isOn || entries.contains(where: { $0.songs != nil }) else { continue }
			let records = PlayHistory.records(for: kind)
			let ranked = ranked(entries, records: records, playCounts: playCounts[kind] ?? [:]).prefix(TopPlays.maximumCount)
			topPlays.entries[kind.rawValue] = await written(ranked, records: records, in: coversURL)
			// Years have no favorites
			let favoriteKeys = kind == .year ? [] : defaults.favorites(for: kind.rawValue).map { $0.normalized() }
			let favorites = favoriteKeys.compactMap { key in entries.first { $0.id.normalized() == key } }.prefix(TopPlays.maximumCount)
			topPlays.favorites[kind.rawValue] = await written(favorites, records: records, in: coversURL)
			topPlays.names[kind.rawValue] = entries.map(\.id)
		}
		guard topPlays.save() else { return }
		removeUnusedCovers(keeping: Set([topPlays.entries, topPlays.favorites].flatMap(\.values).joined().compactMap(\.cover)), in: coversURL)
		WidgetCenter.shared.reloadAllTimelines()
#if !targetEnvironment(macCatalyst)
		ControlCenter.shared.reloadAllControls()
#endif
		HeartBeatsShortcuts.updateAppShortcutParameters()
		await indexForSpotlight(try? await LibraryItemQuery().suggestedEntities())
	}

	private static func written(_ entries: some Collection<MediaEntry>, records: [String: PlayRecord], in coversURL: URL) async -> [TopPlays.Entry] {
		var written: [TopPlays.Entry] = []
		for entry in entries {
			let cover = await writeCover(for: entry, in: coversURL)
			let songs = MediaPlayerValue(value: entry.songs ?? [])
			let songIDs = await MediaPlayerQueue.run { songs.value.map(\.persistentID) }
			written.append(TopPlays.Entry(name: entry.id, songCount: entry.songCount, plays: records[entry.id.normalized()]?.count ?? 0, cover: cover, songIDs: songIDs))
		}
		return written
	}

	/// Spotlight finds the favorites and most played, and a tap shuffles them.
	private static func indexForSpotlight(_ items: [LibraryItem]?) async {
		guard let items else { return }
		let index = CSSearchableIndex.default()
		do {
			try await index.deleteAppEntities(ofType: LibraryItem.self)
			try await index.indexAppEntities(items)
		} catch {
			log.error("Unable to index for Spotlight: \(error)")
		}
	}

	/// Saves the entry's cover as a small JPEG, named by its artwork so an unchanged cover isn't written again.
	private static func writeCover(for entry: MediaEntry, in directory: URL) async -> String? {
		let name: String
		let image: () async -> UIImage?
		if let artwork = entry.albumArtwork {
			name = "\(artwork.id.replacing("/", with: "-")).jpg"
			image = { await ArtworkCache.image(for: artwork, size: coverSize) }
		} else if SampleLibrary.isOn, let sample = UIImage(named: "\(entry.id).jpeg") {
			name = "sample-\(entry.id.replacing("/", with: "-")).jpg"
			image = { sample }
		} else {
			return nil
		}
		let url = directory.appending(path: name)
		if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
			return name
		}
		guard let data = await image()?.jpegData(compressionQuality: 0.85) else { return nil }
		do {
			try data.write(to: url, options: .atomic)
			return name
		} catch {
			log.error("Unable to save widget cover: \(error)")
			return nil
		}
	}

	private static func removeUnusedCovers(keeping used: Set<String>, in directory: URL) {
		let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
		for file in files where !used.contains(file) {
			try? FileManager.default.removeItem(at: directory.appending(path: file))
		}
	}
}

/// Counts a play for the widget, and for artists and genres also marks it played, which makes one of the first three played a favorite.
func recordPlay(of name: String, kind: PlayKind, at date: Date = .now) {
	PlayHistory.record(name, kind: kind, at: date)
	RecentPlays.shared.count += 1
	guard kind != .year else { return }
	let groupBy = kind.rawValue
	let defaults = UserDefaults.standard
	let played = defaults.played(for: groupBy)
	guard !played.containsNormalized(name) else { return }
	let favorites = defaults.favorites(for: groupBy)
	if favorites.count < 3 {
		defaults.setFavorites(favorites + [name], for: groupBy)
	}
	defaults.setPlayed(played + [name], for: groupBy)
}
