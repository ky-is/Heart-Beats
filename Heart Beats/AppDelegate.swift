import UIKit

import MediaPlayer

let SCREENSHOT_MODE = false
let SCREENSHOT_OBSCURED = true

var songCollectionsViewController: SongCollectionsViewController?

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		Zephyr.sync(defaults: [ #keyPath(UserDefaults.showGenres): false, #keyPath(UserDefaults.played): [], #keyPath(UserDefaults.favorited): [], #keyPath(UserDefaults.combined): [], #keyPath(UserDefaults.playedGenres): [], #keyPath(UserDefaults.favoritedGenres): [], #keyPath(UserDefaults.combinedGenres): [], #keyPath(UserDefaults.purchased): false, #keyPath(UserDefaults.minimum): 0 ])
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.purchased), options: [.new], context: nil)

		handleAuthorization(status: MPMediaLibrary.authorizationStatus())

		SongCollections.observe()
		return true
	}

	private func handleAuthorization(status: MPMediaLibraryAuthorizationStatus) {
		switch status {
		case .notDetermined:
			MPMediaLibrary.requestAuthorization(handleAuthorization)
		case .authorized:
			DispatchQueue.main.async(execute: SongCollections.shared.update)
		default:
			songCollectionsViewController?.setUnavailable(status: status)
		}
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		SongCollections.shared.update()
	}

}
