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
		// First, so the lists load with the favorites and settings from other devices
		UserDefaults.keepSynced()
		// The sample library needs no access (and the simulator has no library to ask for)
		if !SampleLibrary.isOn {
			handleAuthorization(status: MPMediaLibrary.authorizationStatus())
		}
		observeMemoryWarnings()
		MinimumSongsTip.configure()
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.fontDesign(.rounded)
				.frame(minWidth: 320, minHeight: 320)
#if targetEnvironment(macCatalyst)
				.onAppear {
					// After SwiftUI's own limits are applied, which cap the window at its launch size
					DispatchQueue.main.async {
						for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
#if DEBUG
							// Screenshot runs (the sample library): a fixed 1440 x 900 window, 2880 x 1800 on a Retina display, the largest Mac App Store size
							if SampleLibrary.isOn {
								let size = Self.screenshotWindowSize
								scene.sizeRestrictions?.minimumSize = size
								scene.sizeRestrictions?.maximumSize = size
								// The window is already up at its launch (or restored) size by now, so it's resized too, not only limited, and moved to
								// the screen's top-left corner, since macOS shrinks a window that would run off the screen
								scene.requestGeometryUpdate(.Mac(systemFrame: CGRect(origin: .zero, size: size)))
								continue
							}
#endif
							scene.sizeRestrictions?.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
						}
					}
				}
#endif
		}
#if targetEnvironment(macCatalyst)
			// Just wide enough for the list to fill the window
			.defaultSize(width: 640, height: 860)
#endif
			.windowResizability(.contentMinSize)
#if targetEnvironment(macCatalyst)
			.commands { HeartBeatsCommands() }
#endif
	}

#if DEBUG && targetEnvironment(macCatalyst)
	static let screenshotWindowSize = CGSize(width: Double(UserDefaults.standard.string(forKey: "screenshotWidth") ?? "") ?? 1440, height: Double(UserDefaults.standard.string(forKey: "screenshotHeight") ?? "") ?? 900)
#endif
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
		// After the lists, so the widget has years too without the Years tab being opened
		YearsCollection.shared.updateIfLibraryChanged(after: .seconds(2))
		observeLibraryChanges()
#if targetEnvironment(macCatalyst)
		MacPlayback.prewarm()
#endif
#if DEBUG && targetEnvironment(macCatalyst)
		debugPlayIfAsked()
#endif
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
			YearsCollection.shared.updateIfLibraryChanged(after: .seconds(1))
		}
	}
}

#if DEBUG && targetEnvironment(macCatalyst)
/// Mac checks: -debugPlay 3 plays that many library songs as a tap would, without opening Music in front of what the user is doing
private func debugPlayIfAsked() {
	guard let count = Int(UserDefaults.standard.string(forKey: "debugPlay") ?? "") else { return }
	Task {
		try? await Task.sleep(for: .seconds(2))
		playSongs(Array((MPMediaQuery.songs().items ?? []).prefix(count)), addToQueue: false)
	}
}
#endif
