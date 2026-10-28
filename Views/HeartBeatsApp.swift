import SwiftUI
import UIKit
import MediaPlayer

@main
struct HeartBeatsApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	init() {
//		UserDefaults.standard.cachedArtists = nil //SAMPLE
//		UserDefaults.standard.cachedGenres = nil

#if !targetEnvironment(simulator)
		handleAuthorization(status: MPMediaLibrary.authorizationStatus())
#endif
		UserDefaults.keepSynced()
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
		GroupedCollection.updateCurrent(withAnimation: true)
		GroupedCollection.updateBackground()
	default:
		GroupedCollection.setUnavailable(status: status)
	}
}

