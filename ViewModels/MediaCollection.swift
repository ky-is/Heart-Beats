import MediaPlayer
import os
import SwiftUI

/// The built-in sample library for screenshots, instead of the music library: always in the simulator, which has none, and
/// in a Debug Mac build launched with `-screenshotData YES`. Off everywhere else, as a constant, so Release builds drop it.
nonisolated enum SampleLibrary {
#if targetEnvironment(simulator)
	static let isOn = true
#elseif DEBUG && targetEnvironment(macCatalyst)
	static let isOn = UserDefaults.standard.bool(forKey: "screenshotData")
#else
	static let isOn = false
#endif

	/// For screenshot runs, which wait for this console line instead of a fixed delay: SCREEN is drawn, covers and all.
	/// Called once the screen has appeared and had a moment to lay out.
	static func ready(_ screen: String) async {
		guard isOn else { return }
		try? await Task.sleep(for: .milliseconds(400))
		print("[screenshot] ready \(screen)")
	}
}

// Built off the main thread by the library scans. MediaPlayer items and artwork aren't marked Sendable, but they're read-only snapshots of the library.
nonisolated struct MediaEntry: @unchecked Sendable, Identifiable, Hashable {
	let id: String
	let songs: [MPMediaItem]?
	let songCount: Int
	let artwork: MPMediaItemArtwork?
	/// Identifies the artwork across rescans, which return new artwork objects for the same album
	let artworkID: MPMediaEntityPersistentID?

	init(id: String, songs: [MPMediaItem]?, songCount: Int, artwork: MPMediaItemArtwork?, artworkID: MPMediaEntityPersistentID? = nil) {
		self.id = id
		self.songs = songs
		self.songCount = songCount
		self.artwork = artwork
		self.artworkID = artworkID
	}

	/// The entry's cover, from its first song that has one.
	init(id: String, songs: [MPMediaItem]) {
		let coverSong = songs.first { $0.artwork != nil }
		self.init(id: id, songs: songs, songCount: songs.count, artwork: coverSong?.artwork, artworkID: coverSong?.artworkID)
	}

	var albumArtwork: ArtworkCache.Artwork? {
		artwork.map { ArtworkCache.Artwork($0, id: artworkID) }
	}

	// Skips comparing every song, which List selection would otherwise do on each check
	static func == (lhs: Self, rhs: Self) -> Bool {
		// Cached entries have no songs, so a loaded entry never equals its cached placeholder
		lhs.id == rhs.id && lhs.songCount == rhs.songCount && lhs.artworkID == rhs.artworkID && (lhs.artwork == nil) == (rhs.artwork == nil) && (lhs.songs == nil) == (rhs.songs == nil)
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}

nonisolated extension MPMediaItem {
	/// The album's ID, which its songs' artwork shares, or the song's own for a song without an album
	var artworkID: MPMediaEntityPersistentID {
		albumPersistentID != 0 ? albumPersistentID : persistentID
	}
}

extension MediaEntry {
	/// The screenshot artists, shown in this order as one list (the simulator has no favorites section), with neighboring covers in different colors
	static let screenshotData = [
		MediaEntry(id: "The Album Leaf", songs: nil, songCount: 20, artwork: nil),
		MediaEntry(id: "Deafheaven", songs: nil, songCount: 21, artwork: nil),
		MediaEntry(id: "Bon Iver", songs: nil, songCount: 25, artwork: nil),
		MediaEntry(id: "Death Cab for Cutie", songs: nil, songCount: 59, artwork: nil),
		MediaEntry(id: "Belle & Sebastian", songs: nil, songCount: 51, artwork: nil),
		MediaEntry(id: "Car Seat Headrest", songs: nil, songCount: 18, artwork: nil),
		MediaEntry(id: "The National", songs: nil, songCount: 61, artwork: nil),
		MediaEntry(id: "Bob Marley & The Wailers", songs: nil, songCount: 33, artwork: nil),
		MediaEntry(id: "The Decemberists", songs: nil, songCount: 52, artwork: nil),
		MediaEntry(id: "The Postal Service", songs: nil, songCount: 19, artwork: nil),
		MediaEntry(id: "Sigur Rós", songs: nil, songCount: 30, artwork: nil),
		MediaEntry(id: "Beach House", songs: nil, songCount: 50, artwork: nil),
		MediaEntry(id: "Polo & Pan", songs: nil, songCount: 16, artwork: nil),
		MediaEntry(id: "indigo la End", songs: nil, songCount: 37, artwork: nil),
		MediaEntry(id: "Frédéric Chopin", songs: nil, songCount: 22, artwork: nil),
		MediaEntry(id: "Stromae", songs: nil, songCount: 15, artwork: nil),
		MediaEntry(id: "Lost Frequencies", songs: nil, songCount: 23, artwork: nil),
		MediaEntry(id: "Sufjan Stevens", songs: nil, songCount: 16, artwork: nil),
		MediaEntry(id: "Toe", songs: nil, songCount: 34, artwork: nil),
		MediaEntry(id: "Yelle", songs: nil, songCount: 26, artwork: nil),
	]

	static let yearsScreenshotData = zip(stride(from: 2026, through: 2019, by: -1), [42, 57, 38, 61, 45, 33, 52, 29]).map {
		MediaEntry(id: String($0), songs: nil, songCount: $1, artwork: nil)
	}

#if targetEnvironment(simulator) || DEBUG
	/// The sample covers (the screenshot artists that have one), so a Years tile shows a collage without a library
	private static let screenshotCovers = screenshotData.compactMap { UIImage(named: "\($0.id).jpeg") }

	/// Each year's sample covers: shuffled with a fixed seed, so every run matches, and none from the three years before it, so no tile shares a cover with its neighbors
	private static let yearsScreenshotCovers: [String: [UIImage]] = {
		var generator = SeededGenerator(seed: 27)
		var recent: [Int] = []
		var covers: [String: [UIImage]] = [:]
		for entry in yearsScreenshotData {
			let picked = Array(screenshotCovers.indices.filter { !recent.contains($0) }.shuffled(using: &generator).prefix(4))
			covers[entry.id] = picked.map { screenshotCovers[$0] }
			recent = Array((recent + picked).suffix(12))
		}
		return covers
	}()

	static func screenshotCovers(forYear id: String, count: Int) -> [UIImage] {
		Array((yearsScreenshotCovers[id] ?? []).prefix(count))
	}

	/// SplitMix64, a small generator that gives the same numbers for the same seed
	private struct SeededGenerator: RandomNumberGenerator {
		var state: UInt64

		init(seed: UInt64) {
			state = seed
		}

		mutating func next() -> UInt64 {
			state &+= 0x9E3779B97F4A7C15
			var z = state
			z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
			z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
			return z ^ (z >> 31)
		}
	}
#endif
}

/// The last scan's names and song counts, kept in a small file in Caches and shown as placeholders on the next launch.
nonisolated struct ListCache {
	private struct Row: Codable, Equatable {
		let id: String
		let songCount: Int
	}

	static let artists = ListCache(name: "artists")
	static let genres = ListCache(name: "genres")
	static let years = ListCache(name: "years")

	let url: URL

	init(name: String, directory: URL = .cachesDirectory) {
		url = directory.appending(path: "\(name).json")
	}

	/// Placeholders without songs, or nil before the first scan.
	func load() -> [MediaEntry]? {
		guard let data = try? Data(contentsOf: url), let rows = try? JSONDecoder().decode([Row].self, from: data) else { return nil }
		return rows.map { MediaEntry(id: $0.id, songs: nil, songCount: $0.songCount, artwork: nil) }
	}

	/// Writes only when the names or counts changed.
	func save(_ entries: [MediaEntry]) {
		let rows = entries.map { Row(id: $0.id, songCount: $0.songCount) }
		// Sorted keys keep the same list byte-for-byte identical, so the comparison below holds
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		guard let data = try? encoder.encode(rows) else { return }
		if let existing = try? Data(contentsOf: url), existing == data {
			return
		}
		do {
			try data.write(to: url, options: .atomic)
		} catch {
			log.error("Unable to save list cache: \(error)")
		}
	}

	/// Earlier versions kept these lists in UserDefaults, which rewrote the settings file after every scan. Moves them here so the next launch still has placeholders.
	static func migrateLegacyDefaults() {
		let defaults = UserDefaults.standard
		for (key, cache) in [("cachedArtists", artists), ("cachedGenres", genres), ("cachedYears", years)] {
			guard let rows = defaults.array(forKey: key) as? [[Any]] else { continue }
			if !FileManager.default.fileExists(atPath: cache.url.path(percentEncoded: false)) {
				cache.save(rows.compactMap { row in
					guard row.count == 2, let id = row[0] as? String, let songCount = row[1] as? Int else { return nil }
					return MediaEntry(id: id, songs: nil, songCount: songCount, artwork: nil)
				})
			}
			defaults.removeObject(forKey: key)
		}
	}
}
