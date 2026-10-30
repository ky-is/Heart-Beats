import AppIntents
import SwiftUI
import WidgetKit

@main
struct HeartBeatsWidgets: WidgetBundle {
	var body: some Widget {
		TopPlaysWidget()
#if !targetEnvironment(macCatalyst)
		ShuffleControl()
#endif
	}
}

struct TopPlaysWidget: Widget {
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: "TopPlays", intent: TopPlaysConfiguration.self, provider: TopPlaysProvider()) { entry in
			TopPlaysView(entry: entry)
				.fontDesign(.rounded)
				.containerBackground(.background, for: .widget)
		}
			.configurationDisplayName("Most Played")
			.description("Your most played or favorite artists, genres or years. Tap one to shuffle it in Music.")
			.supportedFamilies(Self.families)
	}

	private static var families: [WidgetFamily] {
#if targetEnvironment(macCatalyst)
		[.systemSmall, .systemMedium, .systemLarge]
#else
		[.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular]
#endif
	}
}

enum TopPlaysList: String, AppEnum {
	case mostPlayed, favorites

	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Order"
	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.mostPlayed: "Most Played",
		.favorites: "Favorites",
	]
}

struct TopPlaysConfiguration: WidgetConfigurationIntent {
	static let title: LocalizedStringResource = "Most Played"
	static let description = IntentDescription("Choose which artists, genres or years to show.")

	@Parameter(title: "Show", default: .artist)
	var kind: PlayKind

	@Parameter(title: "From", default: .mostPlayed)
	var list: TopPlaysList
}

struct TopPlaysEntry: TimelineEntry {
	let date: Date
	let kind: PlayKind
	/// Years have no favorites, so they always show the most played
	let showsFavorites: Bool
	let entries: [TopPlays.Entry]

	var title: String {
		switch (kind, showsFavorites) {
		case (.artist, false): "Most Played Artists"
		case (.genre, false): "Most Played Genres"
		case (.year, _): "Most Played Years"
		case (.artist, true): "Favorite Artists"
		case (.genre, true): "Favorite Genres"
		}
	}
}

struct TopPlaysProvider: AppIntentTimelineProvider {
	func placeholder(in context: Context) -> TopPlaysEntry {
		TopPlaysEntry(date: .now, kind: .artist, showsFavorites: false, entries: Self.placeholderEntries)
	}

	func snapshot(for configuration: TopPlaysConfiguration, in context: Context) async -> TopPlaysEntry {
		let entry = entry(for: configuration)
		// The widget gallery shows a filled widget before the app has written anything
		return entry.entries.isEmpty && context.isPreview ? TopPlaysEntry(date: .now, kind: entry.kind, showsFavorites: entry.showsFavorites, entries: Self.placeholderEntries) : entry
	}

	// The app reloads the widget whenever its plays or lists change
	func timeline(for configuration: TopPlaysConfiguration, in context: Context) async -> Timeline<TopPlaysEntry> {
		Timeline(entries: [entry(for: configuration)], policy: .never)
	}

	private func entry(for configuration: TopPlaysConfiguration) -> TopPlaysEntry {
		let kind = configuration.kind
		let showsFavorites = configuration.list == .favorites && kind != .year
		let topPlays = TopPlays.load()
		let entries = (showsFavorites ? topPlays?.favorites(for: kind) : topPlays?.entries(for: kind)) ?? []
		return TopPlaysEntry(date: .now, kind: kind, showsFavorites: showsFavorites, entries: entries)
	}

	private static let placeholderEntries = ["The National", "Beach House", "Bon Iver", "Sigur Rós", "The Postal Service", "Deafheaven", "Stromae", "Toe", "Yelle"].map {
		TopPlays.Entry(name: $0, songCount: 20, plays: 0, cover: nil, songIDs: [])
	}
}

struct TopPlaysView: View {
	let entry: TopPlaysEntry

	@Environment(\.widgetFamily) private var family

	private var emptyText: String {
		entry.showsFavorites ? "Favorite \(entry.kind.rawValue)s in Heart Beats to see them here" : "Open Heart Beats to see your \(entry.kind.rawValue)s here"
	}

	var body: some View {
		if entry.entries.isEmpty {
			emptyView
		} else {
			switch family {
			case .systemSmall:
				SmallView(kind: entry.kind, entry: entry.entries[0])
			case .systemMedium, .systemLarge:
				let columns = family == .systemLarge ? 3 : 4
				let rows = family == .systemLarge ? 3 : 1
				VStack(alignment: .leading, spacing: 8) {
					Text(entry.title)
						.font(.caption.weight(.semibold))
						.foregroundStyle(.secondary)
						.accessibilityAddTraits(.isHeader)
					Grid(horizontalSpacing: 10, verticalSpacing: 8) {
						ForEach(0..<rows, id: \.self) { row in
							GridRow {
								ForEach(0..<columns, id: \.self) { column in
									let index = row * columns + column
									if index < entry.entries.count {
										Tile(kind: entry.kind, entry: entry.entries[index])
									} else {
										Color.clear
									}
								}
							}
						}
					}
				}
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			default:
#if targetEnvironment(macCatalyst)
				EmptyView()
#else
				LockScreenView(family: family, kind: entry.kind, entry: entry.entries[0])
#endif
			}
		}
	}

	@ViewBuilder
	private var emptyView: some View {
		switch family {
		case .systemSmall, .systemMedium, .systemLarge:
			VStack(spacing: 6) {
				Image(systemName: "heart.fill")
					.font(.title2)
					.foregroundStyle(.pink)
				Text(emptyText)
					.font(.footnote)
					.multilineTextAlignment(.center)
					.foregroundStyle(.secondary)
			}
		default:
			Image(systemName: "heart.fill")
				.font(.title2)
				.accessibilityLabel(emptyText)
		}
	}
}

/// The top entry alone, filling the widget.
private struct SmallView: View {
	let kind: PlayKind
	let entry: TopPlays.Entry

	var body: some View {
		Button(intent: WidgetShuffleIntent(item: LibraryItem(kind: kind, name: entry.name))) {
			VStack(alignment: .leading, spacing: 6) {
				Cover(entry: entry)
				Text(entry.name)
					.font(.caption.weight(.semibold))
					.lineLimit(1)
					.foregroundStyle(.primary)
			}
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(entry.name)
				.accessibilityHint("Plays shuffled in Music")
		}
			.buttonStyle(.plain)
	}
}

private struct Tile: View {
	let kind: PlayKind
	let entry: TopPlays.Entry

	var body: some View {
		Button(intent: WidgetShuffleIntent(item: LibraryItem(kind: kind, name: entry.name))) {
			VStack(spacing: 4) {
				Cover(entry: entry)
				Text(entry.name)
					.font(.caption2.weight(.medium))
					.lineLimit(1)
					.foregroundStyle(.primary)
			}
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(entry.name)
				.accessibilityHint("Plays shuffled in Music")
		}
			.buttonStyle(.plain)
	}
}

#if !targetEnvironment(macCatalyst)
/// The Lock Screen's top entry: its cover in a circle, or its cover and name.
private struct LockScreenView: View {
	let family: WidgetFamily
	let kind: PlayKind
	let entry: TopPlays.Entry

	var body: some View {
		Button(intent: WidgetShuffleIntent(item: LibraryItem(kind: kind, name: entry.name))) {
			Group {
				if family == .accessoryCircular {
					Cover(entry: entry, circular: true)
				} else {
					HStack(spacing: 8) {
						Cover(entry: entry, cornerRadius: 6)
						Text(entry.name)
							.font(.headline)
							.lineLimit(3)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
			}
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(entry.name)
				.accessibilityHint("Plays shuffled in Music")
		}
			.buttonStyle(.plain)
	}
}

/// A Control Center, Lock Screen or Action button control that shuffles a chosen artist, genre or year, or the most played artist.
struct ShuffleControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		AppIntentControlConfiguration(kind: "Shuffle", provider: ShuffleControlProvider()) { item in
			ControlWidgetButton(action: WidgetShuffleIntent(item: item)) {
				Label(item.name.isEmpty ? "Shuffle" : item.name, systemImage: "shuffle")
			}
		}
			.displayName("Shuffle")
			.description("Shuffles an artist, genre or year from Heart Beats in Music.")
	}
}

struct ShuffleControlConfiguration: ControlConfigurationIntent {
	static let title: LocalizedStringResource = "Shuffle"

	@Parameter(title: "Artist, Genre or Year", description: "Leave empty for your most played artist.")
	var item: LibraryItem?
}

struct ShuffleControlProvider: AppIntentControlValueProvider {
	func previewValue(configuration: ShuffleControlConfiguration) -> LibraryItem {
		configuration.item ?? LibraryItem(kind: .artist, name: "")
	}

	func currentValue(configuration: ShuffleControlConfiguration) async throws -> LibraryItem {
		configuration.item ?? TopPlays.load()?.entries(for: .artist).first.map { LibraryItem(kind: .artist, name: $0.name) } ?? LibraryItem(kind: .artist, name: "")
	}
}
#endif

private struct Cover: View {
	let entry: TopPlays.Entry
	/// Round on the Lock Screen's circular widget
	var circular = false
	var cornerRadius: CGFloat = 10

	private var image: UIImage? {
		guard let cover = entry.cover, let url = TopPlays.coversURL?.appending(path: cover) else { return nil }
		return UIImage(contentsOfFile: url.path(percentEncoded: false))
	}

	// No widgetAccentedRenderingMode on the art: with it, taps on the cover open the app instead of running the button's intent
	var body: some View {
		Rectangle()
			.fill(.quaternary)
			.aspectRatio(1, contentMode: .fit)
			.overlay {
				if let image {
					Image(uiImage: image)
						.resizable()
						.scaledToFill()
				} else {
					Image(systemName: "music.note.list")
						.resizable()
						.scaledToFit()
						.padding(12)
						.foregroundStyle(.background)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.background(.tertiary)
				}
			}
			.clipShape(circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
	}
}

#Preview(as: .systemMedium) {
	TopPlaysWidget()
} timeline: {
	TopPlaysEntry(date: .now, kind: .artist, showsFavorites: false, entries: ["The National", "Beach House", "Bon Iver", "Sigur Rós"].map { TopPlays.Entry(name: $0, songCount: 20, plays: 3, cover: nil, songIDs: []) })
}

