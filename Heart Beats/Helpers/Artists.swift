//
//  Artists.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/21/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import Foundation

import MediaPlayer

final class Artists: NSObject {

	public var allNames = [String]()

	public static var shared = Artists()

	static func observe() {
		Zephyr.shared.userDefaults.addObserver(shared, forKeyPath: #keyPath(UserDefaults.combined), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(shared, forKeyPath: #keyPath(UserDefaults.minimum), options: [.new], context: nil)

//SAMPLE stress test
//		var combined = Zephyr.shared.userDefaults.combined
//		Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
//			if !combined.isEmpty {
//				combined.removeAll()
//			} else {
//				combined.append(["Aimer", "Belle & Sebastian"])
//			}
//			Zephyr.shared.userDefaults.combined = combined
//		}
	}

	let updateQueue: OperationQueue = {
		var queue = OperationQueue()
		queue.name = "ArtistsQueue"
		queue.qualityOfService = .userInitiated
		return queue
	}()

	func update() {
		guard MPMediaLibrary.authorizationStatus() == .authorized else {
			return
		}
		updateQueue.cancelAllOperations()
		updateQueue.addOperation(updateBlock())
	}

	private func setTitle(enabled: Bool) {
		if let navigationBar = artistTableViewController?.navigationController?.navigationBar {
			let attributes = [ NSAttributedStringKey.foregroundColor: enabled ? UIColor.darkText : UIColor.lightGray ]
			navigationBar.titleTextAttributes = attributes
			navigationBar.largeTitleTextAttributes = attributes

			let transition = CATransition()
			transition.type = kCATransitionFade
			transition.duration = 0.15
			navigationBar.layer.add(transition, forKey: "foregroundColor")
		}
	}

	private func updateBlock() -> BlockOperation {
		setTitle(enabled: false)
		let blockOperation = BlockOperation()
		blockOperation.addExecutionBlock { [weak blockOperation, unowned self] in
			guard let collections = MPMediaQuery.artists().collections else {
				return print("Unable to load music")
			}
			let favorited = Zephyr.shared.userDefaults.favorited
			let combined = Zephyr.shared.userDefaults.combined
			var artists = [ String: (String, MPMediaItem, [MPMediaItem]) ]()
			var maxCount = 0
			var names = [String]()
			for collection in collections {
				guard let representative = collection.representativeItem, var artist = representative.albumArtist ?? representative.artist else {
					print("No artist", collection)
					continue
				}
				if artist.lowercased() == "various artists" {
					continue
				}
				if !names.contains(artist) {
					names.append(artist)
				}

				for combining in combined {
					if let index = combining.index(of: artist), index > 0 {
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
				if songs.count > maxCount {
					maxCount = songs.count
				}

				if artists[artist] != nil {
					artists[artist]!.2.append(contentsOf: songs)
				} else {
					artists[artist] = (artist, representative, songs)
				}
			}
			self.allNames = names
			guard !(blockOperation?.isCancelled ?? true) else {
				return
			}
			var cutoff = Zephyr.shared.userDefaults.minimum
			if cutoff <= 0 {
				cutoff = max(5, maxCount / 3)
			}
			let artistsArray = artists.values
				.filter({ $0.2.count >= cutoff || favorited.contains($0.0) })
				.sorted(by: { $0.0.forSorting() < $1.0.forSorting() })
				.map({ Artist(name: $0.0, songs: MPMediaItemCollection(items: $0.2), songCount: $0.2.count, artwork: $0.1.artwork) })
			DispatchQueue.main.async {
				guard !(blockOperation?.isCancelled ?? true) else {
					return
				}
				artistTableViewController?.setArtists(artistsArray, maxCount, cutoff)
				self.setTitle(enabled: true)
			}
			UserDefaults.standard.cachedArtists = artistsArray.map { [ $0.name, $0.songCount ] }
		}
		return blockOperation
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		update()
	}

}
