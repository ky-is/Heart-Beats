import AppIntents

nonisolated extension PlayKind: AppEnum {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "List"
	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.artist: "Artists",
		.genre: "Genres",
		.year: "Years",
	]

	var singularTitle: String {
		switch self {
		case .artist: "Artist"
		case .genre: "Genre"
		case .year: "Year"
		}
	}
}

/// An artist, genre or year from Heart Beats' lists, for Siri, Shortcuts, Spotlight, the control and the widget.
struct LibraryItem: AppEntity, IndexedEntity {
	static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Artist, Genre or Year", numericFormat: "\(placeholder: .int) artists, genres or years")
	static let defaultQuery = LibraryItemQuery()

	let kind: PlayKind
	let name: String

	/// "artist:Name", so the kind survives being stored by the system
	var id: String {
		"\(kind.rawValue):\(name)"
	}

	init(kind: PlayKind, name: String) {
		self.kind = kind
		self.name = name
	}

	init?(id: String) {
		guard let colon = id.firstIndex(of: ":"), let kind = PlayKind(rawValue: String(id[..<colon])) else { return nil }
		self.init(kind: kind, name: String(id[id.index(after: colon)...]))
	}

	var displayRepresentation: DisplayRepresentation {
		let cover = TopPlays.load()?.entry(kind, named: name)?.cover.flatMap { TopPlays.coversURL?.appending(path: $0) }
		return DisplayRepresentation(title: "\(name)", subtitle: "\(kind.singularTitle)", image: cover.map { .init(url: $0) } ?? .init(systemName: "music.note.list"))
	}
}

/// Finds items in the names the app saves with the widget's snapshot, so it works the same in the app and the widget.
struct LibraryItemQuery: EntityStringQuery {
	func entities(for identifiers: [LibraryItem.ID]) async throws -> [LibraryItem] {
		identifiers.compactMap(LibraryItem.init(id:))
	}

	func entities(matching string: String) async throws -> [LibraryItem] {
		let search = string.trimmingCharacters(in: .whitespaces)
		guard let topPlays = TopPlays.load(), !search.isEmpty else { return [] }
		return PlayKind.allCases.flatMap { kind in
			topPlays.names(for: kind).filter { $0.localizedStandardContains(search) }.map { LibraryItem(kind: kind, name: $0) }
		}
	}

	/// Favorites, then the most played
	func suggestedEntities() async throws -> [LibraryItem] {
		guard let topPlays = TopPlays.load() else { return [] }
		var seen = Set<String>()
		return PlayKind.allCases.flatMap { kind in
			(topPlays.favorites(for: kind) + topPlays.entries(for: kind)).map { LibraryItem(kind: kind, name: $0.name) }
		}
			.filter { seen.insert($0.id).inserted }
	}
}

/// A widget cover's or the control's tap: shuffles in Music like Shuffle, kept apart from it so the app can tell widget use from Siri and Shortcuts use. As an audio playback intent it always runs in Heart Beats, in the background, so `perform()` is the app's (the widget's copy never runs).
struct WidgetShuffleIntent: AudioPlaybackIntent {
	static let title: LocalizedStringResource = "Shuffle from Widget"
	static let isDiscoverable = false

	@Parameter(title: "Artist, Genre or Year")
	var item: LibraryItem

	init() {}

	init(item: LibraryItem) {
		self.item = item
	}
}
