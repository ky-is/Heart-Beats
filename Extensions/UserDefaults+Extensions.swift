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

	/// Lists merged item by item across devices, so adding on one adds to the others instead of replacing them
	private static let merged: [String: any ListMerging] = [
		Key.favorited: MergedList.names(Key.favorited),
		Key.favoritedGenres: MergedList.names(Key.favoritedGenres),
		Key.combined: MergedList.combinations(Key.combined),
		Key.combinedGenres: MergedList.combinations(Key.combinedGenres),
	]

	/// When a synced key was last changed by hand, stored beside it here and in iCloud
	private static func changedKey(_ key: String) -> String {
		key + "Changed"
	}

	/// Mirrors synced keys to iCloud, and applies changes from other devices. Favorites and combined groupings merge (see `MergedList`). Other keys carry the time they were last changed, and only a newer change replaces them, so a device that launches with older values never overwrites another's; values from before these times existed are left alone until they're next changed.
	static func keepSynced() {
		let defaults = UserDefaults.standard
		let cloud = NSUbiquitousKeyValueStore.default
		let syncedKeys = Set(synced.map(\.key))

		/// Takes iCloud's value when it was changed more recently than this device's
		func adoptIfNewer(_ key: String) {
			guard let cloudChanged = cloud.object(forKey: changedKey(key)) as? Date else { return }
			if let localChanged = defaults.object(forKey: changedKey(key)) as? Date, localChanged >= cloudChanged { return }
			defaults.set(cloudChanged, forKey: changedKey(key))
			defaults.set(cloud.object(forKey: key), forKey: key)
		}

		// Listening before asking for the latest, so nothing that arrives in between is missed
		let externalChanges = NotificationCenter.default.notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
		cloud.synchronize()

		// Changes only post a notification when they arrive while the app is running, so ones downloaded while it was closed are compared here. A newer change on this device that hasn't reached iCloud is sent up.
		for key in syncedKeys {
			if let list = merged[key] {
				list.merge(defaults: defaults, cloud: cloud)
				continue
			}
			adoptIfNewer(key)
			if let localChanged = defaults.object(forKey: changedKey(key)) as? Date, (cloud.object(forKey: changedKey(key)) as? Date).map({ localChanged > $0 }) ?? true {
				cloud.set(defaults.object(forKey: key), forKey: key)
				cloud.set(localChanged, forKey: changedKey(key))
			}
		}

		Task {
			for await notification in externalChanges {
				let keys = Set(notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? [])
				for key in syncedKeys {
					if let list = merged[key] {
						if !keys.isDisjoint(with: list.cloudKeys) {
							list.merge(defaults: defaults, cloud: cloud)
						}
					} else if keys.contains(key) || keys.contains(changedKey(key)) {
						adoptIfNewer(key)
					}
				}
			}
		}

		Task {
			var last = Dictionary(uniqueKeysWithValues: synced.map { ($0.key, defaults.object(forKey: $0.key) as? NSObject) })
			for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
				for (key, apply) in synced {
					let value = defaults.object(forKey: key) as? NSObject
					guard value != last[key] else { continue }
					let previous = last[key]
					last[key] = value
					if let list = merged[key] {
						list.recordChange(from: previous, to: value, defaults: defaults, cloud: cloud)
					} else if value != cloud.object(forKey: key) as? NSObject {
						// Matching iCloud means it came from there; anything else is a change made here
						let now = Date.now
						defaults.set(now, forKey: changedKey(key))
						cloud.set(value, forKey: key)
						cloud.set(now, forKey: changedKey(key))
					}
					apply?()
				}
			}
		}
	}
}

private protocol ListMerging {
	/// The list and its edit times, any of which changing in iCloud means a merge
	var cloudKeys: Set<String> { get }
	func merge(defaults: UserDefaults, cloud: NSUbiquitousKeyValueStore)
	func recordChange(from old: Any?, to new: Any?, defaults: UserDefaults, cloud: NSUbiquitousKeyValueStore)
}

/// A synced list merged item by item: when each item was last added and removed, on any device, keyed by its identity. An item is in the list when its latest edit is an add, so lists merge across devices and removals still carry over. Items from before these times count as added long ago: they're merged in, and any removal since wins.
private struct MergedList<Element: Equatable>: ListMerging {
	let key: String
	/// Matches items regardless of case
	let identity: (Element) -> String
	/// Rebuilds an item known only from its edit times
	let item: (String) -> Element

	private var addedKey: String { key + "Added" }
	private var removedKey: String { key + "Removed" }
	var cloudKeys: Set<String> { [key, addedKey, removedKey] }

	private func isIncluded(_ id: String, added: [String: Date], removed: [String: Date]) -> Bool {
		guard let addedAt = added[id] else { return false }
		return removed[id].map { addedAt > $0 } ?? true
	}

	private func newest(_ a: [String: Date], _ b: [String: Date]) -> [String: Date] {
		a.merging(b) { max($0, $1) }
	}

	/// Combines this device's and iCloud's edits, sets the list to what they add up to, and sends any change up.
	func merge(defaults: UserDefaults, cloud: NSUbiquitousKeyValueStore) {
		let localList = defaults.array(forKey: key) as? [Element] ?? []
		let cloudList = cloud.array(forKey: key) as? [Element] ?? []
		let localAdded = defaults.dictionary(forKey: addedKey) as? [String: Date] ?? [:]
		let localRemoved = defaults.dictionary(forKey: removedKey) as? [String: Date] ?? [:]
		let cloudAdded = cloud.dictionary(forKey: addedKey) as? [String: Date] ?? [:]
		let cloudRemoved = cloud.dictionary(forKey: removedKey) as? [String: Date] ?? [:]
		var added = newest(localAdded, cloudAdded)
		let removed = newest(localRemoved, cloudRemoved)
		for id in (localList + cloudList).map(identity) where added[id] == nil && removed[id] == nil {
			added[id] = .distantPast
		}

		// This device's order first, then the others' additions, oldest first
		var list: [Element] = []
		var seen = Set<String>()
		let cloudItems = Dictionary(cloudList.map { (identity($0), $0) }, uniquingKeysWith: { first, _ in first })
		let additions = added.keys.sorted { (added[$0]!, $0) < (added[$1]!, $1) }.map { cloudItems[$0] ?? item($0) }
		for element in localList + additions {
			let id = identity(element)
			if isIncluded(id, added: added, removed: removed) && seen.insert(id).inserted {
				list.append(element)
			}
		}

		if added != localAdded { defaults.set(added, forKey: addedKey) }
		if removed != localRemoved { defaults.set(removed, forKey: removedKey) }
		if list != localList { defaults.set(list, forKey: key) }
		if added != cloudAdded { cloud.set(added, forKey: addedKey) }
		if removed != cloudRemoved { cloud.set(removed, forKey: removedKey) }
		// The plain list too, for older versions of the app
		if list != cloudList { cloud.set(list, forKey: key) }
	}

	/// Stamps items added or removed on this device, then merges. Changes that only apply a merge are already recorded, so they aren't stamped again.
	func recordChange(from old: Any?, to new: Any?, defaults: UserDefaults, cloud: NSUbiquitousKeyValueStore) {
		var added = defaults.dictionary(forKey: addedKey) as? [String: Date] ?? [:]
		var removed = defaults.dictionary(forKey: removedKey) as? [String: Date] ?? [:]
		let oldIDs = Set((old as? [Element] ?? []).map(identity))
		let newIDs = Set((new as? [Element] ?? []).map(identity))
		let now = Date.now
		for id in newIDs.subtracting(oldIDs) where !isIncluded(id, added: added, removed: removed) {
			added[id] = now
		}
		for id in oldIDs.subtracting(newIDs) where isIncluded(id, added: added, removed: removed) {
			removed[id] = now
		}
		defaults.set(added, forKey: addedKey)
		defaults.set(removed, forKey: removedKey)
		merge(defaults: defaults, cloud: cloud)
	}
}

private extension MergedList where Element == String {
	static func names(_ key: String) -> Self {
		Self(key: key, identity: { $0.normalized() }, item: { $0 })
	}
}

private extension MergedList where Element == [String] {
	/// `[into, from]`, where the order matters
	static func combinations(_ key: String) -> Self {
		Self(key: key, identity: { $0.map { $0.normalized() }.joined(separator: "\n") }, item: { $0.components(separatedBy: "\n") })
	}
}
