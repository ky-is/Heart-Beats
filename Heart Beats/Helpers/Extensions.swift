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

	func withoutThe() -> String {
		return lowercased().starts(with: "the ") ? String(dropFirst(4)) : self
	}

}

extension UserDefaults {

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
			return array(forKey: #keyPath(favorited)) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #keyPath(favorited))
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
			return integer(forKey: #keyPath(minimum))
		}
		set(value) {
			set(value, forKey: #keyPath(minimum))
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
