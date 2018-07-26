//
//  AppDelegate.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 13/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

let SCREENSHOT_MODE = false

var artistTableViewController: ArtistTableViewController?

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
		IAP.unlocked = true
		IAP.shared.start()

		Zephyr.sync(defaults: [ #keyPath(UserDefaults.played): [], #keyPath(UserDefaults.favorited): [], #keyPath(UserDefaults.combined): [], #keyPath(UserDefaults.purchased): false, #keyPath(UserDefaults.minimum): 0 ])

		if SCREENSHOT_MODE {
			Zephyr.shared.userDefaults.minimum = 19
			Zephyr.shared.userDefaults.favorited = [ "CHVRCHΞS", "indigo la End", "Lost Frequencies", "The National", "Sigur Rós", "Stromae" ]
		}

		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.purchased), options: [.new], context: nil)

		handleAuthorization(status: MPMediaLibrary.authorizationStatus())

		Artists.observe()
		return true
	}

	private func handleAuthorization(status: MPMediaLibraryAuthorizationStatus) {
		switch status {
		case .notDetermined:
			MPMediaLibrary.requestAuthorization(handleAuthorization)
		case .authorized:
			DispatchQueue.main.async(execute: Artists.shared.update)
		default:
			artistTableViewController?.setUnavailable(status: status)
		}
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if !IAP.unlocked && Zephyr.shared.userDefaults.purchased {
			IAP.shared.restore()
		}
	}

}
