import SwiftUI
import UIKit
import MediaPlayer
import os

@main
struct HeartBeatsApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	init() {
//		try? FileManager.default.removeItem(at: ListCache.artists.url) //SAMPLE
//		try? FileManager.default.removeItem(at: ListCache.genres.url)

		ListCache.migrateLegacyDefaults()
#if !targetEnvironment(simulator)
		handleAuthorization(status: MPMediaLibrary.authorizationStatus())
#endif
		UserDefaults.keepSynced()
		observeMemoryWarnings()
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.fontDesign(.rounded)
				.frame(minWidth: 320, minHeight: 320)
		}
			.windowResizability(.contentMinSize)
	}
}

final class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont.rounded(style: .largeTitle, bold: true)]
		UINavigationBar.appearance().titleTextAttributes = [.font: UIFont.rounded(style: .headline, bold: false)]

		UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.rounded(style: .subheadline, bold: true)], for: .selected)
		UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.rounded(style: .subheadline, bold: false)], for: .normal)

		UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.rounded(style: .caption2, bold: false)], for: .normal)

		UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .accentColor
		return true
	}
}

private func handleAuthorization(status: MPMediaLibraryAuthorizationStatus) {
	switch status {
	case .notDetermined:
		Task {
			handleAuthorization(status: await MPMediaLibrary.requestAuthorization())
		}
	case .authorized:
		GroupedCollection.updateAll(withAnimation: true)
		observeLibraryChanges()
	default:
		GroupedCollection.setUnavailable(status: status)
	}
}

/// Frees what can be rebuilt: decoded artwork, the shared songs and the cached groupings.
private func observeMemoryWarnings() {
	Task {
		for await _ in NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification) {
			log.info("Memory warning: releasing caches")
			ArtworkCache.removeAll()
			MusicLibrary.releaseMemory()
			GroupedCollection.releaseMemory()
		}
	}
}

/// Rescans after the library changes while the app is open (e.g. Music side by side on iPad, or a sync).
private func observeLibraryChanges() {
	MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
	Task {
		for await _ in NotificationCenter.default.notifications(named: .MPMediaLibraryDidChange) {
			// Delayed so a burst of changes causes one rescan
			GroupedCollection.updateAllIfLibraryChanged(after: .seconds(1))
			YearsCollection.shared.updateIfLibraryChanged(onlyIfScanned: true, after: .seconds(1))
		}
	}
}
