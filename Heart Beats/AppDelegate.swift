//
//  AppDelegate.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 13/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

var artistTableViewController: ArtistTableViewController!
var selectedArtist: (String, MPMediaItemCollection)? = nil
var countMax = 0

var allArtists = [String]()

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
		IAP.shared.start()

		Zephyr.sync(defaults: [ #keyPath(UserDefaults.played): [], #keyPath(UserDefaults.favorited): [], #keyPath(UserDefaults.purchased): false ])
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.purchased), options: [.new], context: nil)

		handleAuthorization(status: MPMediaLibrary.authorizationStatus())
		return true
	}

	private func handleAuthorization(status: MPMediaLibraryAuthorizationStatus) {
		switch status {
		case .notDetermined:
			MPMediaLibrary.requestAuthorization(handleAuthorization)
		case .denied:
			print("Denied!")
		case .restricted:
			print("Restricted!")
		case .authorized:
			guard let collections = MPMediaQuery.artists().collections else {
				return print("Unable to load music")
			}
			let favorited = Zephyr.shared.userDefaults.favorited
			let combined = Zephyr.shared.userDefaults.combined
			var artists = [ String: (String, MPMediaItem, [MPMediaItem]) ]()
			countMax = 0
			allArtists.removeAll()
			for collection in collections {
				guard let representative = collection.representativeItem, var artist = representative.albumArtist ?? representative.artist else {
					print("No artist", collection)
					continue
				}
				if !allArtists.contains(artist) {
					allArtists.append(artist)
				}

				for combining in combined {
					if let index = combining.firstIndex(of: artist), index > 0 {
						artist = combining[0]
						break
					}
				}
				var songs = [MPMediaItem]()
				for item in collection.items {
					guard item.rating >= 5 else {
						continue
					}
					songs.append(item)
				}
				if songs.count > countMax {
					countMax = songs.count
				}

				if var existingArtist = artists[artist] {
					existingArtist.2.append(contentsOf: songs)
				} else {
					artists[artist] = (artist, representative, songs)
				}
			}
			var artistsArray = artists.values.map { ($0.0, $0.1, MPMediaItemCollection(items: $0.2)) }
			let cutoff = max(5, countMax / 3)
			artistsArray = artistsArray.filter { $0.2.count > cutoff || favorited.contains($0.0) }
			artistsArray.sort { $0.0.withoutThe() < $1.0.withoutThe() }
			DispatchQueue.main.async {
				artistTableViewController.setArtists(artistsArray)
			}
		}
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if !IAP.unlocked && UserDefaults.standard.purchased {
			IAP.shared.restore()
		}
	}

}
