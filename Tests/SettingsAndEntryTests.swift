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
}
