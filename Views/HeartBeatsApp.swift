import SwiftUI
import UIKit
import MediaPlayer

@main
struct HeartBeatsApp: App {
	init() {
//		UserDefaults.standard.cachedArtists = nil //SAMPLE
//		UserDefaults.standard.cachedGenres = nil

#if !targetEnvironment(simulator)
		handleAuthorization(status: MPMediaLibrary.authorizationStatus())
#endif
		UserDefaults.standard.observe()

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
			MediaCollection.updateCurrent(withAnimation: true)
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
	}
}
