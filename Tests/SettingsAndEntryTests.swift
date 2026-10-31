import Foundation
import MediaPlayer
import Testing
@testable import Heart_Beats

@MainActor
struct PerGroupingSettingsTests {
	private let defaults: UserDefaults

	init() {
		let suite = "HeartBeatsTests.\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: suite)!
		defaults.removePersistentDomain(forName: suite)
	}

	@Test func keepsArtistAndGenreCombinationsApart() {
		defaults.setCombined([["Rock", "Alt Rock"]], for: "genre")
		defaults.setCombined([["Sufjan Stevens", "Sufjan"]], for: "artist")
		#expect(defaults.combined(for: "genre") == [["Rock", "Alt Rock"]])
		#expect(defaults.combined(for: "artist") == [["Sufjan Stevens", "Sufjan"]])
	}

	@Test func keepsArtistAndGenrePlayHistoryApart() {
		defaults.setPlayed(["Pop"], for: "genre")
		#expect(defaults.played(for: "genre") == ["Pop"])
		#expect(defaults.played(for: "artist").isEmpty)
	}

	@Test func ignoresTheSelectedTab() {
		defaults.selectedTab = "years"
		defaults.setCombined([["Toe", "toe."]], for: "artist")
		defaults.selectedTab = "genres"
		#expect(defaults.combined(for: "artist") == [["Toe", "toe."]])
		#expect(defaults.combined(for: "genre").isEmpty)
	}
}

struct MediaEntryTests {
	@Test func cachedPlaceholderDiffersFromLoadedEntry() {
		let cached = MediaEntry(id: "Toe", songs: nil, songCount: 2, artwork: nil)
		let loaded = MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil)
		#expect(cached != loaded)
	}

	@Test func comparesByNameCountAndArtwork() {
		let first = MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil)
		#expect(first == MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil))
		#expect(first != MediaEntry(id: "Toe", songs: [], songCount: 3, artwork: nil))
		#expect(first.hashValue == MediaEntry(id: "Toe", songs: nil, songCount: 9, artwork: nil).hashValue)
	}

	@Test func comparesArtworkByAlbumNotObject() {
		let first = MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil, artworkID: 7)
		#expect(first == MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil, artworkID: 7))
		#expect(first != MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil, artworkID: 8))
	}
}

struct ListCacheTests {
	private let directory = URL.temporaryDirectory.appending(path: "ListCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)

	private func makeCache() throws -> ListCache {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		return ListCache(name: "artists", directory: directory)
	}

	@Test func roundTripsAsPlaceholders() throws {
		let cache = try makeCache()
		#expect(cache.load() == nil)
		cache.save([MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil)])
		#expect(cache.load() == [MediaEntry(id: "Toe", songs: nil, songCount: 2, artwork: nil)])
	}

	@Test func skipsWritingAnUnchangedList() throws {
		let cache = try makeCache()
		let entries = [MediaEntry(id: "Toe", songs: [], songCount: 2, artwork: nil)]
		cache.save(entries)
		let written = try FileManager.default.attributesOfItem(atPath: cache.url.path(percentEncoded: false))[.modificationDate] as? Date
		cache.save(entries)
		let rewritten = try FileManager.default.attributesOfItem(atPath: cache.url.path(percentEncoded: false))[.modificationDate] as? Date
		#expect(written == rewritten)
	}

	@Test func ignoresAnUnreadableFile() throws {
		let cache = try makeCache()
		try Data("not json".utf8).write(to: cache.url)
		#expect(cache.load() == nil)
	}
}

struct SongDetailsCacheTests {
	@Test func savesDetailsWithoutTheirPosition() throws {
		let song = SongDetails(index: 42, id: 7, artist: "Toe", albumArtist: nil, genre: "Post-Rock", rating: 5, isFavoriteSong: true, playCount: 3, dateAdded: Date(timeIntervalSince1970: 100))
		let data = try PropertyListEncoder().encode(SongDetailsCache(modifiedDate: .distantPast, savedDate: .now, songs: [song]))
		let decoded = try PropertyListDecoder().decode(SongDetailsCache.self, from: data).songs[0]
		#expect(decoded.index == 0)
		#expect(decoded.id == 7)
		#expect(decoded.artist == "Toe")
		#expect(decoded.albumArtist == nil)
		#expect(decoded.genre == "Post-Rock")
		#expect(decoded.isFavoriteSong)
		#expect(decoded.playCount == 3)
	}

	@Test func dropsACacheSavedWithoutFavorites() throws {
		struct OldSong: Codable {
			var id: UInt64 = 7, rating = 5, playCount = 3, dateAdded = Date(timeIntervalSince1970: 100)
		}
		struct OldCache: Codable {
			var modifiedDate = Date.distantPast, savedDate = Date.now, songs = [OldSong()]
		}
		let data = try PropertyListEncoder().encode(OldCache())
		#expect(throws: DecodingError.self) { try PropertyListDecoder().decode(SongDetailsCache.self, from: data) }
	}
}
