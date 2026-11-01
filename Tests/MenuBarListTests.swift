import Foundation
import Testing
@testable import Heart_Beats

struct MenuBarListTests {
	private func entry(_ name: String, songs: Int = 10) -> MediaEntry {
		MediaEntry(id: name, songs: nil, songCount: songs, artwork: nil)
	}

	@Test func listsFavoritesFirstThenTheRest() {
		let list = MenuBarList(tab: "artists", favorites: [entry("B")], others: [entry("A"), entry("C")])
		#expect(list.items.map(\.name) == ["B", "A", "C"])
		#expect(list.items.map(\.isFavorite) == [true, false, false])
	}

	@Test func listsEveryEntryInTheListsOrder() {
		let others = (0..<500).map { entry("Artist \($0)", songs: 500 - $0) }
		let list = MenuBarList(tab: "artists", favorites: [entry("Favorite")], others: others)
		#expect(list.items.count == 501)
		#expect(list.items.dropFirst().map(\.name) == others.map(\.id))
	}

	@Test func namesEachEntrysSongCount() {
		let list = MenuBarList(tab: "years", favorites: [], others: [entry("2025", songs: 42)])
		#expect(list.propertyList["tab"] as? String == "years")
		let items = list.propertyList["items"] as? [[String: Any]]
		#expect(items?.first?["name"] as? String == "2025")
		#expect(items?.first?["songCount"] as? Int == 42)
	}
}
