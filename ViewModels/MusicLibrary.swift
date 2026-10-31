import MediaPlayer
import os

/// Every song in the library as of one modification date. MediaPlayer items aren't marked Sendable, but they're read-only snapshots of the library.
nonisolated struct LibrarySongs: @unchecked Sendable {
	let modifiedDate: Date
	let items: [MPMediaItem]
	/// The fields the scans read, fetched together for each song. Reading them one by one from the items is a database query each.
	let details: [SongDetails]

	/// The library items for songs picked from `details`.
	func items(for songs: [SongDetails]) -> [MPMediaItem] {
		songs.map { items[$0.index] }
	}
}

/// Carries MediaPlayer items between threads. They aren't marked Sendable, but they're read-only snapshots of the library, and only the MediaPlayer queue calls into them.
nonisolated struct MediaPlayerValue<Value>: @unchecked Sendable {
	let value: Value
}

/// A song's fields for grouping, read once per library change. Only songs some list can show are kept: 5-star and favorited songs, and songs played more than once for Years.
nonisolated struct SongDetails: LibrarySong, Sendable, Codable {
	/// Its position in `LibrarySongs.items`; not saved, since positions change between reads
	var index = 0
	let id: MPMediaEntityPersistentID
	let artist: String?
	let albumArtist: String?
	let genre: String?
	let rating: Int
	let isFavoriteSong: Bool
	let playCount: Int
	let dateAdded: Date

	// isFavoriteSong is required, so a cache saved before it existed (which left out favorited songs below 5 stars) fails to decode and the library is read again
	private enum CodingKeys: CodingKey {
		case id, artist, albumArtist, genre, rating, isFavoriteSong, playCount, dateAdded
	}

	init(index: Int, id: MPMediaEntityPersistentID, artist: String?, albumArtist: String?, genre: String?, rating: Int, isFavoriteSong: Bool, playCount: Int, dateAdded: Date) {
		self.index = index
		self.id = id
		self.artist = artist
		self.albumArtist = albumArtist
		self.genre = genre
		self.rating = rating
		self.isFavoriteSong = isFavoriteSong
		self.playCount = playCount
		self.dateAdded = dateAdded
	}

	// One request for every field measured faster than a cheap request for all songs plus a second for the 5-star and favorited ones' names
	private static let properties: Set<String> = [MPMediaItemPropertyPersistentID, MPMediaItemPropertyRating, MPMediaItem.likedStateProperty, MPMediaItemPropertyPlayCount, MPMediaItemPropertyDateAdded, MPMediaItemPropertyArtist, MPMediaItemPropertyAlbumArtist, MPMediaItemPropertyGenre]

	/// Reads a song in one request, or nil when no list can include it.
	init?(index: Int, item: MPMediaItem) {
		let values = Self.values(of: item, for: Self.properties)
		let rating = (values[MPMediaItemPropertyRating] as? NSNumber)?.intValue ?? 0
		let isFavoriteSong = (values[MPMediaItem.likedStateProperty] as? NSNumber)?.intValue == 2
		let playCount = (values[MPMediaItemPropertyPlayCount] as? NSNumber)?.intValue ?? 0
		guard rating >= 5 || isFavoriteSong || playCount > 1 else { return nil }
		self.init(index: index, id: (values[MPMediaItemPropertyPersistentID] as? NSNumber)?.uint64Value ?? 0, artist: values[MPMediaItemPropertyArtist] as? String, albumArtist: values[MPMediaItemPropertyAlbumArtist] as? String, genre: values[MPMediaItemPropertyGenre] as? String, rating: rating, isFavoriteSong: isFavoriteSong, playCount: playCount, dateAdded: values[MPMediaItemPropertyDateAdded] as? Date ?? .distantPast)
	}

	private typealias EnumerateBlock = @convention(block) (NSString, AnyObject?, UnsafeMutablePointer<ObjCBool>) -> Void
	private typealias EnumerateMethod = @convention(c) (AnyObject, Selector, NSSet, EnumerateBlock) -> Void

	private static let enumerateSelector = unsafe #selector(MPMediaEntity.enumerateValues(forProperties:using:))

	/// Fetches several fields in one request, rather than one per property.
	private static func values(of item: MPMediaItem, for properties: Set<String>) -> [String: AnyObject] {
		var values: [String: AnyObject] = [:]
		// enumerateValues(forProperties:using:) passes nil for a missing field (like a song without a genre), but Swift imports the value as non-optional and crashes on it, so this calls the same method with an optional value.
		let enumerate = unsafe unsafeBitCast(item.method(for: enumerateSelector), to: EnumerateMethod.self)
		let block: EnumerateBlock = { property, value, _ in
			values[property as String] = value
		}
		unsafe enumerate(item, enumerateSelector, properties as NSSet, block)
		return values
	}
}

/// The listed songs' details from the last full read, so a launch with an unchanged library skips reading every song again.
nonisolated struct SongDetailsCache: Codable {
	let modifiedDate: Date
	let savedDate: Date
	let songs: [SongDetails]

	/// Play counts may change without the library's modification date, so a full read still happens at least daily
	static let maximumAge: TimeInterval = 24 * 60 * 60

	static let url = URL.cachesDirectory.appending(path: "songs.plist")

	static func load(modifiedDate: Date) -> SongDetailsCache? {
		guard let data = try? Data(contentsOf: url), let cache = try? PropertyListDecoder().decode(SongDetailsCache.self, from: data) else { return nil }
		guard cache.modifiedDate == modifiedDate, Date.now.timeIntervalSince(cache.savedDate) < maximumAge else { return nil }
		return cache
	}

	static func save(_ songs: [SongDetails], modifiedDate: Date) {
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		do {
			try encoder.encode(SongDetailsCache(modifiedDate: modifiedDate, savedDate: .now, songs: songs)).write(to: url, options: .atomic)
		} catch {
			log.error("Unable to save song details: \(error)")
		}
	}
}

/// Where every MediaPlayer call that touches the library runs: queries, song details and artwork lookups on one queue, cover decodes on another.
///
/// These calls block their thread while they wait on the music library, sometimes on work that needs another free thread. Swift concurrency has one thread per core, so enough of them at once (like a screenful of covers decoding) blocked every thread and deadlocked the scans. Dispatch queues can block without starving anything else, and keeping decodes apart means a screenful of covers never holds up a list.
nonisolated enum MediaPlayerQueue {
	private static let library = DispatchQueue(label: "is.ky.Heart-Beats.media-player.library", qos: .userInitiated)
	private static let artwork = DispatchQueue(label: "is.ky.Heart-Beats.media-player.artwork", qos: .userInitiated)

	/// Runs library reads and entry building.
	static func run<Result: Sendable>(_ work: @escaping @Sendable () -> Result) async -> Result {
		await run(on: library, work)
	}

	/// Runs cover decodes.
	static func runArtwork<Result: Sendable>(_ work: @escaping @Sendable () -> Result) async -> Result {
		await run(on: artwork, work)
	}

	private static func run<Result: Sendable>(on queue: DispatchQueue, _ work: @escaping @Sendable () -> Result) async -> Result {
		await withCheckedContinuation { continuation in
			queue.async {
				continuation.resume(returning: work())
			}
		}
	}
}

/// Reads the music library once per change, shared by the Artists, Genres and Years scans.
enum MusicLibrary {
	private static var latest: (modifiedDate: Date, load: Task<LibrarySongs?, Never>)?

	static var modifiedDate: Date {
		MPMediaLibrary.default().lastModifiedDate
	}

	/// The library's songs, queried off the main thread. Scans of an unchanged library reuse the same query, including one still running.
	static func songs() async -> LibrarySongs? {
		let modifiedDate = modifiedDate
		if let latest, latest.modifiedDate == modifiedDate {
			return await latest.load.value
		}
		let load = Task { await query(modifiedDate: modifiedDate) }
		latest = (modifiedDate, load)
		let songs = await load.value
		if songs == nil, latest?.modifiedDate == modifiedDate {
			// Lets the next scan try again
			latest = nil
		}
		return songs
	}

	/// Drops the shared songs under memory pressure; the next scan reads the library again.
	static func releaseMemory() {
		latest = nil
	}

	private nonisolated static func query(modifiedDate: Date) async -> LibrarySongs? {
		await MediaPlayerQueue.run {
			read(modifiedDate: modifiedDate)
		}
	}

	private nonisolated static func read(modifiedDate: Date) -> LibrarySongs? {
		let items = signposter.withIntervalSignpost("Library read", id: signposter.makeSignpostID()) {
			MPMediaQuery.songs().items
		}
		guard let items else {
			log.error("Unable to load music")
			return nil
		}
		let cached = signposter.withIntervalSignpost("Load cached song details", id: signposter.makeSignpostID()) {
			SongDetailsCache.load(modifiedDate: modifiedDate)
		}
		if let cached {
			let details = signposter.withIntervalSignpost("Match cached song details", id: signposter.makeSignpostID(), "\(items.count) songs") {
				var indexes: [MPMediaEntityPersistentID: Int] = [:]
				indexes.reserveCapacity(items.count)
				for (index, item) in items.enumerated() {
					indexes[item.persistentID] = index
				}
				return cached.songs.compactMap { song -> SongDetails? in
					guard let index = indexes[song.id] else { return nil }
					var song = song
					song.index = index
					return song
				}
			}
			// Every cached song still being there confirms the cache matches this library
			if details.count == cached.songs.count {
				return LibrarySongs(modifiedDate: modifiedDate, items: items, details: details)
			}
		}
		let details = signposter.withIntervalSignpost("Read song details", id: signposter.makeSignpostID(), "\(items.count) songs") {
			items.enumerated().compactMap { SongDetails(index: $0.offset, item: $0.element) }
		}
		SongDetailsCache.save(details, modifiedDate: modifiedDate)
		return LibrarySongs(modifiedDate: modifiedDate, items: items, details: details)
	}
}

/// Runs the newest scan, cancelling any earlier one still waiting or running so its result is never applied.
struct LatestScan {
	private var task: Task<Void, Never>?

	mutating func start(after delay: Duration = .zero, _ scan: @escaping @MainActor () async -> Void) {
		task?.cancel()
		task = Task {
			if delay > .zero {
				try? await Task.sleep(for: delay)
			}
			guard !Task.isCancelled else { return }
			await scan()
		}
	}
}
