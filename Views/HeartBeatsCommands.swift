import SwiftUI

extension Notification.Name {
	/// Opens Settings from the menu bar, in the tab that's showing
	static let showSettings = Notification.Name("showSettings")
}

/// The Mac menu bar's Settings item and View menu, with their keyboard shortcuts. iOS gets the same shortcuts from invisible buttons in ContentView instead.
struct HeartBeatsCommands: Commands {
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"
	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode

	var body: some Commands {
		CommandGroup(replacing: .appSettings) {
			Button("Settings…") {
				NotificationCenter.default.post(name: .showSettings, object: nil)
			}
				.keyboardShortcut(",", modifiers: .command)
		}
		CommandGroup(before: .toolbar) {
			Button("Artists") { selectedTab = "artists" }
				.keyboardShortcut("1", modifiers: .command)
			Button("Genres") { selectedTab = "genres" }
				.keyboardShortcut("2", modifiers: .command)
			Button("Years") { selectedTab = "years" }
				.keyboardShortcut("3", modifiers: .command)
			Divider()
			Button("Show as \(listViewMode == "grid" ? "List" : "Grid")") {
				withAnimation {
					listViewMode = listViewMode == "grid" ? "list" : "grid"
				}
			}
				.keyboardShortcut("l", modifiers: .command)
				.disabled(selectedTab == "years")
			Divider()
			Button("More Songs Required") { stepMinimum(by: 1) }
				.keyboardShortcut("=", modifiers: .command)
				.disabled(selectedTab == "years")
			Button("Fewer Songs Required") { stepMinimum(by: -1) }
				.keyboardShortcut("-", modifiers: .command)
				.disabled(selectedTab == "years")
			Divider()
		}
	}
}
