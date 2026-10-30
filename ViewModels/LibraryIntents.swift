import AppIntents
import MediaPlayer

/// Shuffles an artist, genre or year in Music, from Siri, Shortcuts or the Action button.
struct ShuffleIntent: AudioPlaybackIntent {
	static let title: LocalizedStringResource = "Shuffle"
	static let description = IntentDescription("Shuffles an artist, genre or year from Heart Beats in Music.")

	@Parameter(title: "Artist, Genre or Year")
	var item: LibraryItem

	static var parameterSummary: some ParameterSummary {
		Summary("Shuffle \(\.$item)")
	}

	init() {}

	@MainActor
	func perform() async throws -> some IntentResult {
		try await LibraryPlayback.play(item, next: false)
		SiriTip.used()
		return .result()
	}
}

extension WidgetShuffleIntent {
	@MainActor
	func perform() async throws -> some IntentResult {
		try await LibraryPlayback.play(item, next: false)
		WidgetTip.used()
		return .result()
	}
}

/// Queues an artist, genre or year shuffled after the current song.
struct PlayNextIntent: AudioPlaybackIntent {
	static let title: LocalizedStringResource = "Play Next"
	static let description = IntentDescription("Plays an artist, genre or year from Heart Beats shuffled after the current song.")

	@Parameter(title: "Artist, Genre or Year")
	var item: LibraryItem

	static var parameterSummary: some ParameterSummary {
		Summary("Play \(\.$item) next")
	}

	@MainActor
	func perform() async throws -> some IntentResult {
		try await LibraryPlayback.play(item, next: true)
		SiriTip.used()
		return .result()
	}
}

/// Shuffles an artist, genre or year picked at random.
struct ShuffleRandomIntent: AudioPlaybackIntent {
	static let title: LocalizedStringResource = "Shuffle Something"
	static let description = IntentDescription("Shuffles a random artist, genre or year from Heart Beats.")

	@Parameter(title: "From", default: .artist)
	var kind: PlayKind

	static var parameterSummary: some ParameterSummary {
		Summary("Shuffle a random one from \(\.$kind)")
	}

	@MainActor
	func perform() async throws -> some IntentResult {
		guard let name = TopPlays.load()?.names(for: kind).randomElement() else { throw LibraryPlayback.Failure.empty }
		try await LibraryPlayback.play(LibraryItem(kind: kind, name: name), next: false)
		SiriTip.used()
		return .result()
	}
}

/// A Spotlight result's tap: opens Heart Beats and shuffles it.
struct OpenLibraryItemIntent: OpenIntent {
	static let title: LocalizedStringResource = "Shuffle in Heart Beats"
	static let isDiscoverable = false

	@Parameter(title: "Artist, Genre or Year")
	var target: LibraryItem

	@MainActor
	func perform() async throws -> some IntentResult {
		try await LibraryPlayback.play(target, next: false, opensMusic: true)
		return .result()
	}
}

struct HeartBeatsShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(intent: ShuffleIntent(), phrases: ["Shuffle \(\.$item) in \(.applicationName)", "Play \(\.$item) in \(.applicationName)"], shortTitle: "Shuffle", systemImageName: "shuffle")
		AppShortcut(intent: PlayNextIntent(), phrases: ["Play \(\.$item) next in \(.applicationName)", "Queue \(\.$item) in \(.applicationName)"], shortTitle: "Play Next", systemImageName: "text.line.first.and.arrowtriangle.forward")
		AppShortcut(intent: ShuffleRandomIntent(), phrases: ["Shuffle something in \(.applicationName)", "Surprise me in \(.applicationName)"], shortTitle: "Shuffle Something", systemImageName: "dice")
	}
}

enum LibraryPlayback {
	enum Failure: Error, CustomLocalizedStringResourceConvertible {
		case notFound(String)
		case empty

		var localizedStringResource: LocalizedStringResource {
			switch self {
			case .notFound(let name): "Couldn't find songs for \(name) in Heart Beats."
			case .empty: "Open Heart Beats once to load your library."
			}
		}
	}

	/// Shuffles the item's songs, or adds them after the current song, and counts the play. Music is only brought forward when asked (always on a Mac).
	static func play(_ item: LibraryItem, next: Bool, opensMusic: Bool = false) async throws {
		let songs = await songs(for: item)
		guard !songs.isEmpty else { throw Failure.notFound(item.name) }
		recordPlay(of: item.name, kind: item.kind)
		playSongs(songs, addToQueue: next, opensMusic: opensMusic)
	}

	/// The songs saved for the widget when the item is one of those, so a tap plays before the lists load; otherwise the loaded list's.
	private static func songs(for item: LibraryItem) async -> [MPMediaItem] {
		if let ids = TopPlays.load()?.entry(item.kind, named: item.name)?.songIDs {
			let songs = ids.compactMap { id in
				MPMediaQuery(filterPredicates: [MPMediaPropertyPredicate(value: NSNumber(value: id), forProperty: MPMediaItemPropertyPersistentID)]).items?.first
			}
			if !songs.isEmpty {
				return songs
			}
		}
		return await loadedEntry(for: item)?.songs ?? []
	}

	/// The item's entry once its list has songs, scanning the library first when it was launched just for this (waits up to 20 s).
	private static func loadedEntry(for item: LibraryItem) async -> MediaEntry? {
		let key = item.name.normalized()
		for attempt in 0..<100 {
			let entries = TopPlaysWriter.listEntries(for: item.kind)
			if entries.contains(where: { $0.songs != nil }) {
				return entries.first { $0.id.normalized() == key }
			}
			if attempt == 0 {
				switch item.kind {
				case .artist: GroupedCollection.artists.updateIfLibraryChanged()
				case .genre: GroupedCollection.genres.updateIfLibraryChanged()
				case .year: YearsCollection.shared.updateIfLibraryChanged()
				}
			}
			try? await Task.sleep(for: .milliseconds(200))
		}
		return nil
	}
}
