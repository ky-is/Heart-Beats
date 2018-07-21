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

//SAMPLE stress test
//		var combined = Zephyr.shared.userDefaults.combined
//		Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
//			if combined.count > 0 {
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

	func updateBlock() -> BlockOperation {
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
				if !names.contains(artist) {
					names.append(artist)
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
			var artistsArray = artists.values.map { ($0.0, $0.1, MPMediaItemCollection(items: $0.2)) }
			let cutoff = max(5, maxCount / 3)
			artistsArray = artistsArray.filter { $0.2.count > cutoff || favorited.contains($0.0) }
			artistsArray.sort { $0.0.withoutThe() < $1.0.withoutThe() }
			DispatchQueue.main.async {
				guard !(blockOperation?.isCancelled ?? true) else {
					return
				}
				artistTableViewController?.setArtists(artistsArray)
			}
		}
		return blockOperation
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		update()
	}

}
