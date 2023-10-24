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
		let showsUnavailable = Binding(get: { artistsCollection.unavailable != nil }, set: { _,_ in artistsCollection.unavailable = nil })
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
			.alert("Music Unavailable", isPresented: showsUnavailable, actions: {
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
	let content: () -> Content

	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	@State private var showSettings = false

	@AppStorage("listViewMode") private var listViewMode = UIDevice.current.userInterfaceIdiom == .pad ? "grid" : "list"

#if DEBUG
	private let imageIncrement = 3
	func screenshotImages(startIndex: Int) -> [Image] {
		let idealSize = CGSize(width: 128, height: 128)
		return MediaCollection.current.entries.filter({ SyncStorage.shared.showGenres ? true : SyncStorage.shared.currentFavorites.contains($0.id) })[startIndex..<startIndex+imageIncrement].compactMap { $0.artwork?.image(at: idealSize) }.map { Image(uiImage: $0.scale(to: idealSize)) }
	}
#endif

	var body: some View {
		NavigationStack {
			content()
				.toolbar {
					ToolbarItemGroup(placement: .topBarTrailing) {
#if targetEnvironment(simulator) //SAMPLE
//							ShareLink(items: screenshotImages(startIndex: 0)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//							ShareLink(items: screenshotImages(startIndex: imageIncrement)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//							ShareLink(items: screenshotImages(startIndex: imageIncrement * 2)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
#endif
						Button("Show as \(listViewMode)", systemImage: listViewMode == "grid" ? "list.triangle" : "square.grid.2x2") {
							withAnimation {
								listViewMode = listViewMode == "grid" ? "list" : "grid"
							}
						}
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
