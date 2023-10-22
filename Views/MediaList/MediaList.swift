import SwiftUI
import MediaPlayer

struct MediaList: View {
	var collection: MediaCollection

	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?
	@EnvironmentObject private var syncStorage: SyncStorage

	private let imageWidth = 128

	private func play(entry: MediaEntry) {
		Task { @MainActor in
			let entryName = entry.id
			let played = SyncStorage.shared.currentPlayed
			if !played.contains(entryName) {
				var favorites = SyncStorage.shared.currentFavorites
				if favorites.count < 3 {
					favorites.append(entryName)
					if SyncStorage.shared.showGenres {
						SyncStorage.shared.favoritedGenres = favorites
					} else {
						SyncStorage.shared.favorited = favorites
					}
				}
				if SyncStorage.shared.showGenres {
					SyncStorage.shared.playedGenres.append(entryName)
				} else {
					SyncStorage.shared.played.append(entryName)
				}
			}
		}

		Task {
			let player = MPMusicPlayerController.systemMusicPlayer
			player.setQueue(with: entry.songs!)
			player.shuffleMode = .songs
			player.play()
			await openMusicApp()
		}
	}

	private func openMusicApp() async {
		if let url = URL(string: "audio-player-event:"), UIApplication.shared.canOpenURL(url) {
			Task { @MainActor in
				await UIApplication.shared.open(url)
			}
		} else {
			print("Unable to open Music.app")
			//TODO macOS
		}
	}

	private var groupedEntries: [[MediaEntry]] {
		let favorites = UserDefaults.standard.showGenres ? UserDefaults.standard.favoritedGenres : UserDefaults.standard.favorited
		var favoriteEntries: [MediaEntry] = []
		var nonfavoriteEntries: [MediaEntry] = []
		for entry in collection.entries {
			if favorites.contains(entry.id) {
				favoriteEntries.append(entry)
			} else {
				nonfavoriteEntries.append(entry)
			}
		}
		return favoriteEntries.isEmpty ? [nonfavoriteEntries] : [favoriteEntries, nonfavoriteEntries]
	}

	var body: some View {
		let activeSelection = Binding {
			selection
		} set: { newValue in
			withAnimation {
				selection = newValue
			}
			if let newValue {
				play(entry: newValue)
			}
		}
		let allEntriesGroups = groupedEntries
//		let allEntriesGroups: [[MediaEntry]] = [[]] //SAMPLE
		let showHeaders = allEntriesGroups.count > 1
		let hasEntries = !allEntriesGroups[0].isEmpty
		Group {
			if !hasEntries {
				if (collection.groupBy == "genre" ? SyncStorage.shared.cachedGenres : SyncStorage.shared.cachedArtists) == nil {
					List {
						ForEach(MediaCollection.screenshotData) {
							MediaListRow(entry: $0, imageWidth: imageWidth, inFavorites: false, play: play)
						}
					}
						.listStyle(.plain)
						.redacted(reason: .placeholder)
						.navigationTitle("… \(collection.groupBy.capitalized)s")
				} else {
					List {
						Section {} footer: {
							Text("No 5-star songs found in your library…")
								.font(.title)
								.multilineTextAlignment(.center)
								.padding(.top)
								.padding(.horizontal)
						}

						Section("Step 1: Ensure star ratings are enabled") {
							Link(destination: URL(string: "App-prefs:MUSIC")!) {
								Label("Settings > Music >\nEnable \"Show Star Ratings\"", systemImage: "gear.circle.fill")
							}
						}
						Section("Step 2: Rate songs in Music app") {
							Link(destination: URL(string: "audio-player-event:")!) {
								Label("Open Music App to rate", systemImage: "music.note.house.fill")
							}
						}
					}
				}
			} else {
				List(selection: activeSelection) {
					ForEach(allEntriesGroups, id: \.self) { groupEntries in
						let inFavorites = showHeaders && groupEntries == allEntriesGroups[0]
						Section {
							ForEach(groupEntries) { entry in
								MediaListRow(entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
									.tag(entry)
							}
						} header: {
							if showHeaders {
								Text(inFavorites ? "Favorites" : "Uncategorized")
									.font(.headline.smallCaps())
							}
						}
					}
				}
					.listStyle(.plain)
			}
		}
			.navigationTitle(collection.groupBy.capitalized.pluralize(collection.entries.count))
			.onChange(of: scenePhase) { _, newPhase in
				if newPhase == .active {
					withAnimation {
						selection = nil
					}
				}
			}
	}
}

#Preview {
	NavigationStack {
		MediaList(collection: MediaCollection(groupBy: "artist"))
	}
		.fontDesign(.rounded)
}
