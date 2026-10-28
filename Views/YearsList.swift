import SwiftUI
import MediaPlayer
import os

struct YearsList: View {
	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?
	@State private var pendingPlay: PendingPlay?

	@State private var collection = YearsCollection.shared

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode

	// Years don't count toward artist or genre play history and favorites
	private func play(entry: MediaEntry, addToQueue: Bool) {
		guard let songs = entry.songs else {
			pendingPlay = PendingPlay(id: entry.id, addToQueue: addToQueue)
			return
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
		Group {
			if collection.entries.isEmpty {
				List {
					Section {} footer: {
						Text("Not enough play history in your library yet…")
							.font(.title)
							.multilineTextAlignment(.center)
							.padding(.top)
							.padding(.horizontal)
					}

					Section("Songs played more than once show up by the year they were added") {
						Link(destination: URL(string: "audio-player-event:")!) {
							Label("Open Music App", systemImage: "music.note.house.fill")
						}
					}
				}
			} else {
				GridView(groupBy: nil, showHeaders: false, largeTitles: true, allEntriesGroups: [(label: nil, entries: collection.entries)], activeSelection: activeSelection, play: play)
			}
		}
			.navigationTitle("Years In Review")
			.playWhenLoaded($pendingPlay, entries: collection.entries, play: play)
			.onAppear {
				collection.updateIfLibraryChanged()
			}
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

#Preview {
	NavigationStack {
		YearsList()
	}
		.fontDesign(.rounded)
}
