import SwiftUI
import MediaPlayer

private let FavoritesLabel = "Favorites"

struct YearsList: View {
	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?

	@State private var collection = YearsCollection()

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
		Group {
			if collection.entries.isEmpty {
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
			} else {
				GridView(showHeaders: false, largeTitles: true, allEntriesGroups: [(label: nil, entries: collection.entries)], activeSelection: activeSelection, play: play)
			}
		}
			.navigationTitle("Years In Review")
			.onAppear {
				Task {
					await collection.update(withAnimation: false)
				}
			}
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

#Preview {
	NavigationStack {
		YearsList()
	}
		.fontDesign(.rounded)
}
