import SwiftUI
import MediaPlayer
import os

struct YearsList: View {
	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?
	@State private var pendingPlay: PendingPlay?
	/// The year played last, which VoiceOver returns to when Music hands back
	@State private var lastPlayedID: String?
	@AccessibilityFocusState private var focusedEntry: String?
	@Namespace private var rotorNamespace

	@State private var collection = YearsCollection.shared

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode

	// Years don't count toward artist or genre play history and favorites
	private func play(entry: MediaEntry, addToQueue: Bool) {
		lastPlayedID = entry.id
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

					Section {
						Link(destination: URL(string: "audio-player-event:")!) {
							Label("Open Music App", systemImage: "music.note.house.fill")
						}
					} header: {
						SectionTitle("Songs played more than once show up by the year they were added")
					}
				}
			} else {
				GridView(groupBy: nil, showHeaders: false, largeTitles: true, allEntriesGroups: [(label: nil, entries: collection.entries)], activeSelection: activeSelection, focusedEntry: $focusedEntry, rotorNamespace: rotorNamespace, play: play)
			}
		}
			.navigationTitle("Years In Review")
			.playWhenLoaded($pendingPlay, entries: collection.entries, play: play)
			.task { await SampleLibrary.ready("years") }
			.onAppear {
				collection.updateIfLibraryChanged()
			}
			.onChange(of: scenePhase) { _, newPhase in
				// ContentView rescans the library on foreground
				if newPhase == .active {
					withAnimation {
						selection = nil
					}
					// Once, so a later return to the app starts where VoiceOver normally would
					restoreFocus(to: lastPlayedID, focus: $focusedEntry)
					lastPlayedID = nil
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
