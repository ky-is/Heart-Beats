import SwiftUI
import MediaPlayer
import os

typealias ListGroupEntry = (label: String?, entries: [MediaEntry])

struct MediaList: View {
	var collection: GroupedCollection

	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?
	@State private var pendingPlay: PendingPlay?

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode

	private func play(entry: MediaEntry, addToQueue: Bool) {
		guard let songs = entry.songs else {
			pendingPlay = PendingPlay(id: entry.id, addToQueue: addToQueue)
			return
		}

		let groupBy = collection.groupBy
		let defaults = UserDefaults.standard
		let played = defaults.played(for: groupBy)
		if !played.containsNormalized(entry.id) {
			let favorites = defaults.favorites(for: groupBy)
			if favorites.count < 3 {
				defaults.setFavorites(favorites + [entry.id], for: groupBy)
			}
			defaults.setPlayed(played + [entry.id], for: groupBy)
		}
		playSongs(songs, addToQueue: addToQueue)
	}

	var body: some View {
		let activeSelection = Binding {
			selection
		} set: { newValue in
			withAnimation {
				selection = newValue
			}
			if let newValue {
				play(entry: newValue, addToQueue: false)
			}
		}
//		let allEntriesGroups: [ListGroupEntry] = [(nil, [])] //SAMPLE
		let allEntriesGroups = collection.sections
		let hasEntries = !collection.entries.isEmpty
#if targetEnvironment(simulator)
		let showHeaders = false
		let entryCount = 42
#else
		let showHeaders = allEntriesGroups.count > 1
		let entryCount = collection.entries.count
#endif
		Group {
			if !hasEntries {
				EmptyMediaList(collection: collection, listViewMode: listViewMode, imageWidth: 88)
			} else if listViewMode == "grid" {
				GridView(groupBy: collection.groupBy, showHeaders: showHeaders, largeTitles: false, allEntriesGroups: allEntriesGroups, activeSelection: activeSelection, play: play)
			} else {
				ListView(groupBy: collection.groupBy, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: activeSelection, play: play)
			}
		}
			.navigationTitle(collection.groupBy.capitalized.pluralize(entryCount))
			.playWhenLoaded($pendingPlay, entries: collection.entries, play: play)
			.onChange(of: scenePhase) { _, newPhase in
				// ContentView rescans the library on foreground
				if newPhase == .active {
					withAnimation {
						selection = nil
					}
				}
			}
	}
}

struct GridView: View {
	let groupBy: String?
	let showHeaders: Bool
	let largeTitles: Bool
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	let play: (MediaEntry, Bool) -> Void

	private let spacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8

	private func sizeColumns(in geometry: GeometryProxy, spacing: CGFloat) -> (count: Int, width: CGFloat) {
		let idealWidth: CGFloat = geometry.size.width >= 2048 ? 256 : (UIDevice.current.userInterfaceIdiom == .pad ? 176 : 144)
		guard geometry.size.width > 0 else {
			return (3, idealWidth)
		}
		let columnCount = max(1, (geometry.size.width / (idealWidth + spacing * 2)).rounded(.down))
		let columnWidth = geometry.size.width / columnCount - spacing * 1
		return (Int(columnCount), columnWidth)
	}

	var body: some View {
		GeometryReader { geometry in
			let (columnCount, columnSize) = sizeColumns(in: geometry, spacing: spacing)
			ScrollView {
				LazyVGrid(columns: Array(repeating: GridItem(.fixed(columnSize), spacing: spacing), count: columnCount), spacing: spacing * 1.5) {
					EntriesView(groupBy: groupBy, listViewMode: "grid", largeTitles: largeTitles, imageWidth: columnSize - spacing, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: $activeSelection, play: play)
				}
					.padding(.vertical, spacing / 2)
			}
		}
	}
}

private struct ListView: View {
	let groupBy: String
	let showHeaders: Bool
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	let play: (MediaEntry, Bool) -> Void

	var body: some View {
		List(selection: $activeSelection) {
			EntriesView(groupBy: groupBy, listViewMode: "list", largeTitles: false, imageWidth: 128, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: $activeSelection, play: play)
		}
			.listStyle(.plain)
	}
}

private struct EntriesView: View {
	let groupBy: String?
	let listViewMode: String
	let largeTitles: Bool
	let imageWidth: CGFloat
	let showHeaders: Bool
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	let play: (MediaEntry, Bool) -> Void

	var body: some View {
		ForEach(allEntriesGroups, id: \.label) { listGroup in
			Section {
				let inFavorites = listGroup.label == FavoritesLabel
				ForEach(listGroup.entries) { entry in
					if listViewMode == "grid" {
						Button {
							activeSelection = entry
						} label: {
							MediaListEntry(groupBy: groupBy, listViewMode: listViewMode, largeTitles: largeTitles, entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
						}
							.buttonStyle(.plain)
					} else {
						MediaListEntry(groupBy: groupBy, listViewMode: listViewMode, largeTitles: largeTitles, entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
							.tag(entry)
					}
				}
			} header: {
				if showHeaders {
					Text(listGroup.label ?? "Uncategorized")
//						.foregroundStyle(Color.secondary)
						.font(.headline.smallCaps())
				}
			}
		}
	}
}

/// An entry tapped while the list still shows cached entries, which have no songs until the first scan finishes.
struct PendingPlay: Equatable {
	let id: String
	let addToQueue: Bool
}

extension View {
	/// Plays the pending entry once a scan loads its songs.
	func playWhenLoaded(_ pending: Binding<PendingPlay?>, entries: [MediaEntry], play: @escaping (MediaEntry, Bool) -> Void) -> some View {
		onChange(of: entries) { _, entries in
			guard let request = pending.wrappedValue, let entry = entries.first(where: { $0.id.normalized() == request.id.normalized() }), entry.songs != nil else { return }
			pending.wrappedValue = nil
			play(entry, request.addToQueue)
		}
	}
}

/// Plays the songs shuffled in the system player, then opens Music.
func playSongs(_ songs: [MPMediaItem], addToQueue: Bool) {
#if targetEnvironment(macCatalyst)
	let player = MPMusicPlayerController.applicationMusicPlayer
#else
	let player = MPMusicPlayerController.systemMusicPlayer
#endif
	let songCollection = MPMediaItemCollection(items: songs.shuffled())
	if addToQueue {
		player.prepend(MPMusicPlayerMediaItemQueueDescriptor(itemCollection: songCollection))
	} else {
		player.setQueue(with: songCollection)
	}
	player.play()
	Task {
		guard let url = URL(string: "audio-player-event:"), await UIApplication.shared.open(url) else {
			log.error("Unable to open Music.app")
			//TODO macOS
			return
		}
	}
}

#Preview {
	NavigationStack {
		MediaList(collection: GroupedCollection(groupBy: "artist"))
	}
		.fontDesign(.rounded)
}
