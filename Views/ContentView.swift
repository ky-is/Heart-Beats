import MediaPlayer
import SwiftUI

struct ContentView: View {
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	@Environment(\.scenePhase) private var scenePhase

	@State private var artistsCollection = GroupedCollection.artists
	@State private var genresCollection = GroupedCollection.genres

	private var yearSuffix: String.SubSequence {
		Calendar.current.component(.year, from: .now).description.suffix(2)
	}

	var body: some View {
		let selectionTabDisabled = Binding {
			selectedTab.isEmpty ? "artists" : selectedTab
		} set: {
			selectedTab = $0.isEmpty ? "artists" : $0
		}
		let showsUnavailable = Binding(get: { artistsCollection.unavailable != nil }, set: { _,_ in artistsCollection.unavailable = nil })
		TabView(selection: selectionTabDisabled) {
			Tab("Artists", systemImage: "music.mic", value: "artists") {
				NavigationContentView {
					MediaList(collection: artistsCollection)
				}
			}
			Tab("Genres", systemImage: "opticaldisc", value: "genres") {
				NavigationContentView {
					MediaList(collection: genresCollection)
				}
			}
			Tab("Years", systemImage: "\(Int(yearSuffix)! > 50 ? "00" : yearSuffix).square", value: "years") {
				NavigationContentView(canToggle: false) {
					YearsList()
				}
			}
#if !targetEnvironment(macCatalyst)
			Tab("", systemImage: "", value: "", role: .search) {
			}
				.disabled(true)
#endif
		}
			.overlay(alignment: .bottomTrailing) {
				// Years ignore the minimum
				if selectedTab != "years" {
					MinimumSongsButton()
						.padding([.bottom, .trailing], 20)
				}
			}
//				.tabViewBottomAccessory {
//					MinimumSongsStepper()
////					if selectedTab != "years" { //TODO
////					}
//				}
			.tabBarMinimizeBehavior(.onScrollDown)
			.ignoresSafeArea(.container, edges: .bottom)
			.onChange(of: scenePhase) { _, newPhase in
				// Picks up ratings changed in Music; skipped when the library is unchanged
				if newPhase == .active {
					GroupedCollection.updateAllIfLibraryChanged()
					YearsCollection.shared.updateIfLibraryChanged(onlyIfScanned: true)
				}
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
	let canToggle: Bool
	let content: () -> Content

	init(canToggle: Bool = true, @ViewBuilder content: @escaping () -> Content) {
		self.canToggle = canToggle
		self.content = content
	}

	@State private var showSettings = false

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

#if targetEnvironment(simulator)
	private let imageIncrement = 3
	func screenshotImages(startIndex: Int) -> [Image] {
		let idealSize = CGSize(width: 128, height: 128)
		return GroupedCollection.current.entries.filter({ UserDefaults.standard.selectedTab == "genres" ? true : UserDefaults.standard.favorites(for: GroupedCollection.current.groupBy).contains($0.id) })[startIndex..<startIndex+imageIncrement].compactMap { $0.artwork?.image(at: idealSize) }.map { Image(uiImage: $0.scale(to: idealSize)) }
	}
#endif

	var body: some View {
		NavigationStack {
			content()
				.toolbar {
#if targetEnvironment(macCatalyst)
					ToolbarItem(placement: .principal) {
						MinimumSongsButton()
							.disabled(selectedTab == "years")
					}
#endif
//					ToolbarItemGroup(placement: .topBarTrailing) {
//#if targetEnvironment(simulator) //SAMPLE
//							ShareLink(items: screenshotImages(startIndex: 0)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//							ShareLink(items: screenshotImages(startIndex: imageIncrement)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//							ShareLink(items: screenshotImages(startIndex: imageIncrement * 2)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//#endif
						if canToggle {
							ToolbarItem {
								Button("Show as \(listViewMode)", systemImage: listViewMode == "grid" ? "list.triangle" : "square.grid.2x2") {
									withAnimation {
										listViewMode = listViewMode == "grid" ? "list" : "grid"
									}
								}
#if targetEnvironment(macCatalyst)
								.buttonStyle(.borderless)
#endif
							}
						}
						ToolbarSpacer(.fixed)
						ToolbarItem {
							Button("Settings", systemImage: "gearshape") {
								showSettings = true
							}
#if targetEnvironment(macCatalyst)
								.buttonStyle(.borderless)
#endif
						}
//					}
				}
				.sheet(isPresented: $showSettings) {
					SettingsView()
				}
		}
	}
}

#Preview {
	ContentView()
}
