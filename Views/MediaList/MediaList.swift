import SwiftUI
import MediaPlayer

typealias ListGroupEntry = (label: String?, entries: [MediaEntry])

private let FavoritesLabel = "Favorites"

struct MediaList: View {
	var collection: GroupedCollection

	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode

	private func play(entry: MediaEntry, addToQueue: Bool) {
		guard let songs = entry.songs else { return }

		let entryName = entry.id
		let played = UserDefaults.standard.currentPlayed
		if !played.contains(entryName) {
			if UserDefaults.standard.currentFavorites.count < 3 {
				UserDefaults.standard.currentFavorites.append(entryName)
			}
			UserDefaults.standard.currentPlayed.append(entryName)
		}

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
		openMusicApp()
	}

	private func openMusicApp() {
		if let url = URL(string: "audio-player-event:"), UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url)
		} else {
			print("Unable to open Music.app")
			//TODO macOS
		}
	}

	private var groupedEntries: [ListGroupEntry] {
		let favorites = UserDefaults.standard.selectedTab == "genres" ? UserDefaults.standard.favoritedGenres : UserDefaults.standard.favorited
		var favoriteEntries: [MediaEntry] = []
		var nonfavoriteEntries: [MediaEntry] = []
		for entry in collection.entries {
			if favorites.contains(entry.id) {
				favoriteEntries.append(entry)
			} else {
				nonfavoriteEntries.append(entry)
			}
		}
		return favoriteEntries.isEmpty ? [(nil, nonfavoriteEntries)] : [(FavoritesLabel, favoriteEntries), (nil, nonfavoriteEntries)]
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
		let allEntriesGroups = groupedEntries
		let hasEntries = !allEntriesGroups.last!.entries.isEmpty
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
				GridView(showHeaders: showHeaders, largeTitles: false, allEntriesGroups: allEntriesGroups, activeSelection: activeSelection, play: play)
			} else {
				ListView(showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: activeSelection, play: play)
			}
		}
			.navigationTitle(collection.groupBy.capitalized.pluralize(entryCount))
			.onChange(of: scenePhase) { _, newPhase in
				if newPhase == .active {
					GroupedCollection.updateCurrent(withAnimation: false)
					withAnimation {
						selection = nil
					}
				}
			}
	}
}

struct GridView: View {
	let showHeaders: Bool
	let largeTitles: Bool
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	let play: (MediaEntry, Bool) -> Void

	private let idealWidth: CGFloat = UIScreen.main.bounds.width >= 2048 ? 256 : (UIDevice.current.userInterfaceIdiom == .pad ? 176 : 144)
	private let spacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8

	private func sizeColumns(in geometry: GeometryProxy, idealWidth: CGFloat, spacing: CGFloat) -> (count: Int, width: CGFloat) {
		guard geometry.size.width > 0 else {
			return (3, idealWidth)
		}
		let columnCount = (geometry.size.width / (idealWidth + spacing * 2)).rounded(.down)
		let columnWidth = geometry.size.width / columnCount - spacing * 1
		return (Int(columnCount), columnWidth)
	}

	var body: some View {
		GeometryReader { geometry in
			let (columnCount, columnSize) = sizeColumns(in: geometry, idealWidth: idealWidth, spacing: spacing)
			ScrollView {
				LazyVGrid(columns: Array(repeating: GridItem(.fixed(columnSize), spacing: spacing), count: columnCount), spacing: spacing * 1.5) {
					EntriesView(listViewMode: "grid", largeTitles: largeTitles, imageWidth: columnSize - spacing, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: $activeSelection, play: play)
				}
					.padding(.vertical, spacing / 2)
			}
		}
	}
}

private struct ListView: View {
	let showHeaders: Bool
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	let play: (MediaEntry, Bool) -> Void

	var body: some View {
		List(selection: $activeSelection) {
			EntriesView(listViewMode: "list", largeTitles: false, imageWidth: 128, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: $activeSelection, play: play)
		}
			.listStyle(.plain)
	}
}

private struct EntriesView: View {
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
							MediaListEntry(listViewMode: listViewMode, largeTitles: largeTitles, entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
						}
							.buttonStyle(.plain)
					} else {
						MediaListEntry(listViewMode: listViewMode, largeTitles: largeTitles, entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
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

#Preview {
	NavigationStack {
		MediaList(collection: GroupedCollection(groupBy: "artist"))
	}
		.fontDesign(.rounded)
}
