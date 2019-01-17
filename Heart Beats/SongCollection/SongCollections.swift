//
//  SongCollections.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/21/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import Foundation

import MediaPlayer

final class SongCollections: NSObject {

	public var allNames = [String]()

	public static var shared = SongCollections()

	static func observe() {
		Zephyr.shared.userDefaults.addObserver(shared, forKeyPath: #keyPath(UserDefaults.combined), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(shared, forKeyPath: #keyPath(UserDefaults.combinedGenres), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(shared, forKeyPath: #keyPath(UserDefaults.minimum), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(shared, forKeyPath: #keyPath(UserDefaults.showGenres), options: [.new], context: nil)
	}

	let updateQueue: OperationQueue = {
		var queue = OperationQueue()
		queue.name = "SongCollectionsQueue"
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
		if let navigationBar = songCollectionsViewController?.navigationController?.navigationBar {
			let attributes = [ NSAttributedString.Key.foregroundColor: enabled ? UIColor.darkText : UIColor.lightGray ]
			navigationBar.titleTextAttributes = attributes
			navigationBar.largeTitleTextAttributes = attributes

			let transition = CATransition()
			transition.type = .fade
			transition.duration = 0.15
			navigationBar.layer.add(transition, forKey: "foregroundColor")
		}
	}

	private func updateBlock() -> BlockOperation {
		setTitle(enabled: false)
		let blockOperation = BlockOperation()
		blockOperation.addExecutionBlock { [weak blockOperation, unowned self] in
			let showGenres = Zephyr.shared.userDefaults.showGenres
			let query = showGenres ? MPMediaQuery.genres() : MPMediaQuery.artists()
			guard let collections = query.collections else {
				return print("Unable to load music")
			}
			let favorited = Zephyr.shared.userDefaults.getFavorites()
			let combined = Zephyr.shared.userDefaults.getCombined()
			var collectionsByName = [ String: (String, MPMediaItem, [MPMediaItem]) ]()
			var maxCount = 0
			var names = [String]()
			var namesLowercased = [String]()
			for collection in collections {
				guard let representative = collection.representativeItem else {
					print("No artist", collection)
					continue
				}
				var checkNames = [String]()
				if showGenres {
					if let genres = representative.genre?.split(separator: ",") {
						checkNames = genres.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
					}
				} else {
					let albumArtist = representative.albumArtist
					if let albumArtist = albumArtist {
						checkNames.append(albumArtist)
					}
					if let artist = representative.artist, artist != albumArtist {
						checkNames.append(artist)
					}
				}
				guard !checkNames.isEmpty else {
					continue
				}
				for var name in checkNames {
					var checkName = name.lowercased()
					if !showGenres && checkName == "various artists" {
						continue
					}
					if !namesLowercased.contains(checkName) {
						namesLowercased.append(checkName)
						names.append(name)
					}

					for combining in combined {
						if let index = combining.index(of: name), index > 0 {
							name = combining[0]
							checkName = name.lowercased()
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

					if collectionsByName[checkName] != nil {
						collectionsByName[checkName]!.2.append(contentsOf: songs)
					} else {
						collectionsByName[checkName] = (name, representative, songs)
					}
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
			let collectionsArray = collectionsByName.values
				.filter({ $0.2.count >= cutoff || favorited.contains($0.0) })
				.sorted(by: { $0.0.forSorting() < $1.0.forSorting() })
				.map({ SongCollection(name: $0.0, songs: MPMediaItemCollection(items: $0.2), songCount: $0.2.count, artwork: $0.1.artwork) })
			DispatchQueue.main.async {
				guard !(blockOperation?.isCancelled ?? true) else {
					return
				}
				songCollectionsViewController?.setCollections(collectionsArray, maxCount, cutoff)
				self.setTitle(enabled: true)
			}
			let cache = collectionsArray.map { [ $0.name, $0.songCount ] }
			if showGenres {
				UserDefaults.standard.cachedGenres = cache
			} else {
				UserDefaults.standard.cachedArtists = cache
			}
		}
		return blockOperation
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		DispatchQueue.main.async(execute: update)
	}

}
