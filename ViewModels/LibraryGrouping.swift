import Foundation
import MediaPlayer

/// The song fields the grouping logic reads, so it can be tested without a music library.
nonisolated protocol LibrarySong {
	var artist: String? { get }
	var albumArtist: String? { get }
	var genre: String? { get }
	var rating: Int { get }
	var playCount: Int { get }
	var dateAdded: Date { get }
}

nonisolated extension MPMediaItem: LibrarySong {}

/// Pure grouping rules for the Artists, Genres and Years lists.
nonisolated enum LibraryGrouping {
	/// The largest minimum the stepper offers.
	static let minimumSongsCap = 99

	struct Group<Song> {
		var name: String
		var songs: [Song]
	}

	/// The names a song is listed under. An artist song gets one name, so it's never counted twice.
	static func names(for song: some LibrarySong, groupBy: String) -> [String] {
		if groupBy == "genre" {
			return (song.genre ?? "")
				.split(separator: ",")
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
		}
		// The album artist keeps featured tracks with the album's artist; compilations fall back to the track artist
		for candidate in [song.albumArtist, song.artist] {
			guard let name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty, name.normalized() != "various artists" else { continue }
			return [name]
		}
		return []
	}

	/// Groups 5-star songs by artist or genre. Names match regardless of case, and `combined` entries are `[into, from...]`.
	static func group<Song: LibrarySong>(_ songs: [Song], groupBy: String, combined: [[String]]) -> [Group<Song>] {
		var combineInto: [String: String] = [:]
		for combination in combined where combination.count >= 2 {
			for from in combination.dropFirst() {
				combineInto[from.normalized()] = combination[0]
			}
		}

		var groups: [String: Group<Song>] = [:]
		for song in songs where song.rating >= 5 {
			var seenKeys = Set<String>()
			for rawName in names(for: song, groupBy: groupBy) {
				let combinedName = combineInto[rawName.normalized()]
				let name = combinedName ?? rawName
				let key = name.normalized()
				// A song listed under two names that combine into one still counts once
				guard seenKeys.insert(key).inserted else { continue }
				groups[key, default: Group(name: name, songs: [])].songs.append(song)
				if let combinedName {
					groups[key]!.name = combinedName
				}
			}
		}
		return Array(groups.values)
	}

	/// Keeps groups with at least `minimum` songs (capped to the largest group) plus favorites, sorted ignoring a leading "The".
	static func select<Song>(_ groups: [Group<Song>], minimum: Int, favorites: [String]) -> (groups: [Group<Song>], mostSongsLimit: Int) {
		let mostSongsLimit = min(minimumSongsCap, groups.map(\.songs.count).max() ?? 0)
		let effectiveMinimum = min(minimum, mostSongsLimit)
		let favoriteKeys = Set(favorites.map { $0.normalized() })
		let selected = groups
			.filter { !$0.songs.isEmpty && ($0.songs.count >= effectiveMinimum || favoriteKeys.contains($0.name.normalized())) }
			.sorted {
				let order = $0.name.forSorting.localizedStandardCompare($1.name.forSorting)
				return order == .orderedSame ? $0.name < $1.name : order == .orderedAscending
			}
		return (selected, mostSongsLimit)
	}

	/// Each year's most played songs, by the year they were added (the library has no per-year play history). Newest year first.
	static func yearsInReview<Song: LibrarySong>(_ songs: [Song], calendar: Calendar) -> [(year: Int, songs: [Song])] {
		var years: [Int: [Song]] = [:]
		for song in songs where song.playCount > 1 {
			years[calendar.component(.year, from: song.dateAdded), default: []].append(song)
		}

		var result: [(year: Int, songs: [Song])] = []
		for (year, entries) in years {
			let maxPlayCount = max(100, entries.map(\.playCount).max() ?? 0)
			let halfPlayCount = Int(Double(maxPlayCount) * 0.5)
			let minPlayCount = Int(Double(maxPlayCount) * 0.1)
			let songs = entries
				.filter { $0.playCount >= minPlayCount && ($0.playCount > halfPlayCount || $0.rating >= 5) }
				.sorted { $0.playCount > $1.playCount }
			if songs.count >= 5 {
				result.append((year, songs))
			}
		}
		return result.sorted { $0.year > $1.year }
	}
}
