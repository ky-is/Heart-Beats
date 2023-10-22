import SwiftUI
import UIKit
import MediaPlayer

#if DEBUG
let SCREENSHOT_MODE = false //SAMPLE
#endif

@main
struct HeartBeatsApp: App {
	init() {
//		SyncStorage.shared.cachedArtists = nil //SAMPLE
//		SyncStorage.shared.cachedGenres = nil

#if !targetEnvironment(simulator)
		handleAuthorization(status: MPMediaLibrary.authorizationStatus())
#endif

		UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont.rounded(style: .largeTitle, bold: true)]
		UINavigationBar.appearance().titleTextAttributes = [.font: UIFont.rounded(style: .headline, bold: false)]

		UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.rounded(style: .subheadline, bold: true)], for: .selected)
		UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.rounded(style: .subheadline, bold: false)], for: .normal)

		UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.rounded(style: .caption2, bold: false)], for: .normal)

		UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .accentColor
	}

	private func handleAuthorization(status: MPMediaLibraryAuthorizationStatus) {
		switch status {
		case .notDetermined:
			MPMediaLibrary.requestAuthorization(handleAuthorization)
		case .authorized:
			MediaCollection.updateCurrent()
			MediaCollection.updateBackground()
		default:
			MediaCollection.setUnavailable(status: status)
		}
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.tint(.accent)
				.fontDesign(.rounded)
		}
			.environmentObject(SyncStorage.shared)
	}
}
