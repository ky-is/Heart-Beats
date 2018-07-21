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

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
			var artists = [ (String, MPMediaItem, MPMediaItemCollection) ]()
			for collection in collections {
				guard let representative = collection.representativeItem, let artist = representative.artist ?? representative.albumArtist else {
					print("No artist", collection)
					continue
				}
				var songs = [MPMediaItem]()
				for item in collection.items {
					guard item.rating >= 5 else {
						continue
					}
					songs.append(item)
				}
				artists.append((artist, representative, MPMediaItemCollection(items: songs)))
			}
			artists = artists.filter { $0.2.count > 9 }
			artists.sort { $0.0 < $1.0 }
			DispatchQueue.main.async {
				artistTableViewController.setArtists(artists)
			}
		}
	}

}
