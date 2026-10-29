import MediaPlayer
import os
import SwiftUI

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
	static let screenshotData = [
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
