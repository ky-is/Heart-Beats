import Foundation
import MediaPlayer

/// The song fields the grouping logic reads, so it can be tested without a music library.
nonisolated protocol LibrarySong {
	var artist: String? { get }
	var albumArtist: String? { get }
	var genre: String? { get }
	var rating: Int { get }
	/// Favorited in Music (the heart, later a star)
	var isFavoriteSong: Bool { get }
	var playCount: Int { get }
	var dateAdded: Date { get }
}

nonisolated extension LibrarySong {
	/// Rated 5 stars or favorited in Music, the songs the Artists and Genres lists play
	var isTopRated: Bool {
		rating >= 5 || isFavoriteSong
	}
}

nonisolated extension MPMediaItem: LibrarySong {
	/// MediaPlayer's undocumented favorite state: 2 is favorited, 3 disliked, 0 or 1 neither
	static let likedStateProperty = "likedState"

	var isFavoriteSong: Bool {
		(value(forProperty: Self.likedStateProperty) as? NSNumber)?.intValue == 2
	}
}

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

	/// Groups 5-star and favorited songs by artist or genre. Names match regardless of case, and `combined` entries are `[into, from...]`.
	static func group<Song: LibrarySong>(_ songs: [Song], groupBy: String, combined: [[String]]) -> [Group<Song>] {
		let combineInto = combineInto(combined)
		var groups: [String: Group<Song>] = [:]
		for song in songs where song.isTopRated {
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

	/// Each combined-away name (normalized) mapped to the name it's combined into.
	private static func combineInto(_ combined: [[String]]) -> [String: String] {
		var combineInto: [String: String] = [:]
		for combination in combined where combination.count >= 2 {
			for from in combination.dropFirst() {
				combineInto[from.normalized()] = combination[0]
			}
		}
		return combineInto
	}

	/// How many times Music has played each artist's or genre's songs, all ratings included, keyed by normalized name after combinations.
	static func playCounts(_ songs: [some LibrarySong], groupBy: String, combined: [[String]]) -> [String: Int] {
		let combineInto = combineInto(combined)
		var counts: [String: Int] = [:]
		for song in songs where song.playCount > 0 {
			var seenKeys = Set<String>()
			for rawName in names(for: song, groupBy: groupBy) {
				let key = (combineInto[rawName.normalized()] ?? rawName).normalized()
				guard seenKeys.insert(key).inserted else { continue }
				counts[key, default: 0] += song.playCount
			}
		}
		return counts
	}

	/// How many times Music has played the songs added each year, keyed by year.
	static func yearPlayCounts(_ songs: [some LibrarySong], calendar: Calendar) -> [String: Int] {
		var counts: [String: Int] = [:]
		for song in songs where song.playCount > 0 {
			counts[calendar.component(.year, from: song.dateAdded).description, default: 0] += song.playCount
		}
		return counts
	}

	/// Keeps groups with at least `minimum` songs (capped to the largest group) plus favorites, sorted ignoring a leading "The".
	static func select<Song>(_ groups: [Group<Song>], minimum: Int, favorites: [String]) -> (groups: [Group<Song>], mostSongsLimit: Int) {
		let mostSongsLimit = min(minimumSongsCap, groups.map(\.songs.count).max() ?? 0)
		let effectiveMinimum = min(minimum, mostSongsLimit)
		let favoriteKeys = Set(favorites.map { $0.normalized() })
		// Sort keys are built once per group rather than on every comparison
		let selected = groups
			.filter { !$0.songs.isEmpty && ($0.songs.count >= effectiveMinimum || favoriteKeys.contains($0.name.normalized())) }
			.map { (sortKey: $0.name.forSorting, group: $0) }
			.sorted {
				let order = $0.sortKey.localizedStandardCompare($1.sortKey)
				return order == .orderedSame ? $0.group.name < $1.group.name : order == .orderedAscending
			}
			.map(\.group)
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
				.filter { $0.playCount >= minPlayCount && ($0.playCount > halfPlayCount || $0.isTopRated) }
				.sorted { $0.playCount > $1.playCount }
			if songs.count >= 5 {
				result.append((year, songs))
			}
		}
		return result.sorted { $0.year > $1.year }
	}
}
