import SwiftUI

struct ContentView: View {
	@EnvironmentObject private var syncStorage: SyncStorage

	var body: some View {
		GeometryReader { geometry in
			TabView(selection: $syncStorage.showGenres) {
				TabsContent()
			}
				.overlay(alignment: .bottom) {
					MinimumSongsButton(geometry: geometry)
				}
		}
	}
}

private struct TabsContent: View {
	@State private var artistsCollection = MediaCollection.artists
	@State private var genresCollection = MediaCollection.genres

	var body: some View {
		Group {
			NavigationContentView {
				MediaList(collection: artistsCollection)
			}
				.tabItem { //TODO scroll to top
					Label("Artists", systemImage: "music.mic")
				}
				.tag(false)
			NavigationContentView {
				MediaList(collection: genresCollection)
			}
				.tabItem {
					Label("Genres", systemImage: "opticaldisc")
				}
				.tag(true)
		}
			.alert("Music Unavailable", isPresented: Binding(get: { artistsCollection.unavailable != nil }, set: { _,_ in artistsCollection.unavailable = nil }), actions: {
				Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
			}) {
				let detail: String = switch artistsCollection.unavailable {
				case .restricted:
					"change your library restrictions"
				default:
					"change your permissions"
				}
				Text("Heart Beats requires access to your music library in order to create playlists based on your favorite artists.\n\nPlease \(detail) in the Settings app and try again.")
			}
	}
}

private struct NavigationContentView<Content: View>: View {
	@State private var showSettings = false

	let content: () -> Content

	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	var body: some View {
		NavigationStack {
			content()
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						Button("Settings", systemImage: "gearshape") {
							showSettings = true
						}
					}
				}
				.sheet(isPresented: $showSettings) {
					SettingsView()
				}
		}
	}
}

#Preview {
	ContentView()
		.tint(.accent)
		.environmentObject(SyncStorage.shared)
}
