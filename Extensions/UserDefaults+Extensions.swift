import UIKit

extension UserDefaults {
	struct Key {
		static let played = "played"
		static let favorited = "favorited"
		static let combined = "combined"
		static let playedGenres = "playedGenres"
		static let favoritedGenres = "favoritedGenres"
		static let combinedGenres = "combinedGenres"
		static let selectedTab = "selectedTab"
		static let minimum = "minimum"

		// Unsynced

		static let listViewMode = "listViewMode"
	}

	var played: [String] {
		get {
			array(forKey: #function) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var playedGenres: [String] {
		get {
			array(forKey: #function) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var favorited: [String] {
		get {
			array(forKey: #function) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var favoritedGenres: [String] {

		get {
			if SampleLibrary.isOn {
				return ["Classical", "Française", "Hip-Hop", "K-Pop", "J-Rock", "Post-Rock", "Reggae"]
			}
			return array(forKey: #function) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var combined: [[String]] {
		get {
			array(forKey: #function) as? [[String]] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var combinedGenres: [[String]] {
		get {
			array(forKey: #function) as? [[String]] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var selectedTab: String {
		get {
			string(forKey: #function) ?? "artists"
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	var minimum: Int {
		get {
			if SampleLibrary.isOn {
				return 15
			}
			let stored = integer(forKey: UserDefaults.Key.minimum)
			return stored <= 0 ? 15 : stored
		}
		set(value) {
			set(value, forKey: #function)
		}
	}

	// Unsycned

	var listViewMode: String {
		get {
			// Grid on iPad and Mac (where the idiom is .mac when optimized for Mac, .pad otherwise), list on iPhone
			return string(forKey: UserDefaults.Key.listViewMode) ?? ([.pad, .mac].contains(UIDevice.current.userInterfaceIdiom) ? "grid" : "list")
		}
		set(value) {
			set(value, forKey: UserDefaults.Key.listViewMode)
		}
	}

	// Per grouping ("artist" or "genre"), independent of the selected tab

	func played(for groupBy: String) -> [String] {
		groupBy == "genre" ? playedGenres : played
	}
	func setPlayed(_ value: [String], for groupBy: String) {
		if groupBy == "genre" {
			playedGenres = value
		} else {
			played = value
		}
	}
	func favorites(for groupBy: String) -> [String] {
		groupBy == "genre" ? favoritedGenres : favorited
	}
	func setFavorites(_ value: [String], for groupBy: String) {
		if groupBy == "genre" {
			favoritedGenres = value
		} else {
			favorited = value
		}
	}
	func combined(for groupBy: String) -> [[String]] {
		groupBy == "genre" ? combinedGenres : combined
	}
	func setCombined(_ value: [[String]], for groupBy: String) {
		if groupBy == "genre" {
			combinedGenres = value
		} else {
			combined = value
		}
	}

	// Sync

	private static let synced: [(key: String, apply: (() -> Void)?)] = [
		(Key.played, nil),
		(Key.favorited, { GroupedCollection.artists.scheduleUpdate(withAnimation: true) }),
		(Key.combined, { GroupedCollection.artists.scheduleUpdate(withAnimation: true) }),
		(Key.playedGenres, nil),
		(Key.favoritedGenres, { GroupedCollection.genres.scheduleUpdate(withAnimation: true) }),
		(Key.combinedGenres, { GroupedCollection.genres.scheduleUpdate(withAnimation: true) }),
		(Key.selectedTab, { GroupedCollection.updateCurrent(withAnimation: false) }),
		// Only filters the cached grouping, so each stepper tap applies right away
		(Key.minimum, { GroupedCollection.updateAll(withAnimation: true) }),
	]

	/// Mirrors synced keys to iCloud, and applies changes from other devices.
	static func keepSynced() {
		let defaults = UserDefaults.standard
		let cloud = NSUbiquitousKeyValueStore.default
		let syncedKeys = Set(synced.map(\.key))
		// Pulls the latest iCloud values; changes arrive as didChangeExternally notifications
		cloud.synchronize()

		Task {
			for await notification in NotificationCenter.default.notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
				let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
				for key in keys where syncedKeys.contains(key) {
					defaults.set(cloud.object(forKey: key), forKey: key)
				}
			}
		}

		Task {
			var last = Dictionary(uniqueKeysWithValues: synced.map { ($0.key, defaults.object(forKey: $0.key) as? NSObject) })
			for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
				for (key, apply) in synced {
					let value = defaults.object(forKey: key) as? NSObject
					guard value != last[key] else { continue }
					last[key] = value
					cloud.set(value, forKey: key)
					apply?()
				}
			}
		}
	}
}
