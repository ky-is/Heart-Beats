import Foundation

/// What the Mac menu bar item lists for one tab: every entry, favorites first, each group in the list's order.
nonisolated struct MenuBarList: Equatable, Sendable {
	struct Item: Equatable, Sendable {
		let name: String
		let songCount: Int
		let isFavorite: Bool
		/// Its cover, which the menu bar shows beside the name
		let artwork: ArtworkCache.Artwork?
	}

	/// "artists", "genres" or "years"
	let tab: String
	let items: [Item]

	init(tab: String, favorites: [MediaEntry], others: [MediaEntry]) {
		self.tab = tab
		items = favorites.map { Item(name: $0.id, songCount: $0.songCount, isFavorite: true, artwork: $0.albumArtwork) } + others.map { Item(name: $0.id, songCount: $0.songCount, isFavorite: false, artwork: $0.albumArtwork) }
	}

	/// The list as the menu bar bundle reads it, which shares no types with the app: only property list values. Covers are sent apart (see `MenuBar`), so an item only names its cover.
	var propertyList: [String: Any] {
		["tab": tab, "items": items.map { item -> [String: Any] in
			var values: [String: Any] = ["name": item.name, "songCount": item.songCount, "isFavorite": item.isFavorite]
			values["cover"] = item.artwork?.id
			return values
		}]
	}
}
