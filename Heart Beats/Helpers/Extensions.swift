//
//  Extensions.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

extension Bundle {

	var version: String {
		return infoDictionary!["CFBundleShortVersionString"] as! String
	}

}

extension Collection {

	subscript (safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}

}

extension String {

	func plural(_ amount: Int) -> String {
		return amount == 1 ? self : "\(self)s"
	}

	func forSorting() -> String {
		let result = lowercased()
		return result.starts(with: "the ") ? String(result.dropFirst(4)) : result
	}

}

extension UserDefaults {

	func getPlayed() -> [String] {
		return showGenres ? playedGenres : played
	}

	func getFavorites() -> [String] {
		return showGenres ? favoritedGenres : favorited
	}

	func getCombined() -> [[String]] {
		return getCombined(showGenres: showGenres)
	}

	func getCombined(showGenres: Bool) -> [[String]] {
		return showGenres ? combinedGenres : combined
	}

	// Artists

	@objc dynamic var played: [String] {
		get {
			return array(forKey: #keyPath(played)) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(played))
		}
	}

	@objc dynamic var favorited: [String] {
		get {
			if SCREENSHOT_MODE {
				return [ "CHVRCHΞS", "indigo la End", "Lost Frequencies", "The National", "Sigur Rós", "Stromae" ]
			}
			return array(forKey: #keyPath(favorited)) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(favorited))
		}
	}

	@objc dynamic var combined: [[String]] {
		get {
			return array(forKey: #keyPath(combined)) as? [[String]] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(combined))
		}
	}

	// Genres

	@objc dynamic var playedGenres: [String] {
		get {
			return array(forKey: #keyPath(playedGenres)) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(playedGenres))
		}
	}

	@objc dynamic var favoritedGenres: [String] {
		get {
			if SCREENSHOT_MODE {
				return [ "Classical", "French", "Hip-Hop", "K-Pop", "Post-Rock", "Reggae" ]
			}
			return array(forKey: #keyPath(favoritedGenres)) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(favoritedGenres))
		}
	}

	@objc dynamic var combinedGenres: [[String]] {
		get {
			return array(forKey: #keyPath(combinedGenres)) as? [[String]] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(combinedGenres))
		}
	}

	// Synced

	@objc dynamic var showGenres: Bool {
		get {
			return bool(forKey: #keyPath(showGenres))
		}
		set(value) {
			set(value, forKey: #keyPath(showGenres))
		}
	}

	@objc dynamic var purchased: Bool {
		get {
			return bool(forKey: #keyPath(purchased))
		}
		set(value) {
			set(value, forKey: #keyPath(purchased))
		}
	}

	@objc dynamic var minimum: Int {
		get {
			return SCREENSHOT_MODE ? 20 : integer(forKey: #keyPath(minimum))
		}
		set(value) {
			set(value, forKey: #keyPath(minimum))
		}
	}


	// Local

	@objc dynamic var cachedArtists: [[Any]]? {
		get {
			return array(forKey: #keyPath(cachedArtists)) as? [[Any]]
		}
		set(value) {
			set(value, forKey: #keyPath(cachedArtists))
		}
	}

	@objc dynamic var cachedGenres: [[Any]]? {
		get {
			return array(forKey: #keyPath(cachedGenres)) as? [[Any]]
		}
		set(value) {
			set(value, forKey: #keyPath(cachedGenres))
		}
	}

}

extension UIImage {

	var zero: UIImage {
		return UIImage()
	}

}

extension UIViewController {

	func alert(_ title: String, message: String, cancel: String, customAction: UIAlertAction? = nil, cancelAction: UIAlertAction? = nil) {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let cancelAction = cancelAction ?? UIAlertAction(title: cancel, style: customAction == nil ? .cancel : .default, handler: nil)
		alertController.addAction(cancelAction)
		if let customAction = customAction {
			alertController.addAction(customAction)
		}
		present(alertController, animated: true, completion: nil)
	}

}
