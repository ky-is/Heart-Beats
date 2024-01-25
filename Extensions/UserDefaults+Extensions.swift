import UIKit

private var observers: [NSKeyValueObservation] = []

extension UserDefaults {
	struct Key {
		static let played = "played"
		static let favorited = "favorited"
		static let combined = "combined"
		static let playedGenres = "playedGenres"
		static let favoritedGenres = "favoritedGenres"
		static let combinedGenres = "combinedGenres"
		static let showGenres = "showGenres"
		static let minimum = "minimum"

		// Unsynced

		static let listViewMode = "listViewMode"
		static let cachedArtists = "cachedArtists"
		static let cachedGenres = "cachedGenres"
	}

	@objc dynamic var played: [String] {
		get {
			array(forKey: #function) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var playedGenres: [String] {
		get {
			array(forKey: #function) as? [String] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var favorited: [String] {
		get {
#if targetEnvironment(simulator)
			return ["Beach House", "Frédéric Chopin", "indigo la End", "Lost Frequencies", "Polo & Pan", "Stromae", "Sufjan Stevens", "Toe", "Yelle"]
#else
			array(forKey: #function) as? [String] ?? []
#endif
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var favoritedGenres: [String] {

		get {
#if targetEnvironment(simulator)
			return ["Classical", "Française", "Hip-Hop", "K-Pop", "J-Rock", "Post-Rock", "Reggae"]
#else
			return array(forKey: #function) as? [String] ?? []
#endif
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var combined: [[String]] {
		get {
			array(forKey: #function) as? [[String]] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var combinedGenres: [[String]] {
		get {
			array(forKey: #function) as? [[String]] ?? []
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var showGenres: Bool {
		get {
			bool(forKey: #function)
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var minimum: Int {
		get {
#if targetEnvironment(simulator)
			return 15
#else
			let stored = integer(forKey: UserDefaults.Key.minimum)
			return stored <= 0 ? 15 : stored
#endif
		}
		set(value) {
			set(value, forKey: #function)
		}
	}

	// Unsycned

	var listViewMode: String {
		get {
			return string(forKey: UserDefaults.Key.listViewMode) ?? (UIDevice.current.userInterfaceIdiom == .pad ? "grid" : "list")
		}
		set(value) {
			set(value, forKey: UserDefaults.Key.listViewMode)
		}
	}

	var cachedArtists: [[Any]]? {
		get {
			return array(forKey: UserDefaults.Key.cachedArtists) as? [[Any]]
		}
		set(value) {
			set(value, forKey: UserDefaults.Key.cachedArtists)
		}
	}
	var cachedGenres: [[Any]]? {
		get {
			return array(forKey: UserDefaults.Key.cachedGenres) as? [[Any]]
		}
		set(value) {
			set(value, forKey: UserDefaults.Key.cachedGenres)
		}
	}


	var currentPlayed: [String] {
		get {
			return showGenres ? playedGenres : played
		}
		set(value) {
			if showGenres {
				playedGenres = value
			} else {
				played = value
			}
		}
	}
	var currentFavorites: [String] {
		get {
			return showGenres ? favoritedGenres : favorited
		}
		set(value) {
			if showGenres {
				favoritedGenres = value
			} else {
				favorited = value
			}
		}
	}
	var currentCombined: [[String]] {
		get {
			return showGenres ? combinedGenres : combined
		}
		set(value) {
			if showGenres {
				combinedGenres = value
			} else {
				combined = value
			}
		}
	}

	// Sync

	func observe() {
		NotificationCenter.default.addObserver(self, selector: #selector(didChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)

		keepSynced(\.played)
		keepSynced(\.favorited)
		keepSynced(\.combined)
		keepSynced(\.playedGenres)
		keepSynced(\.favoritedGenres)
		keepSynced(\.combinedGenres)
		keepSynced(\.showGenres) {
			MediaCollection.updateCurrent(withAnimation: false)
		}
		keepSynced(\.minimum) {
			MediaCollection.updateCurrent(withAnimation: true)
		}
	}

	func keepSynced<Value>(_ keyPath: KeyPath<UserDefaults, Value>, apply: (() -> Void)? = nil) {
		observers.append(observe(keyPath) { defaults, change in
			let value = defaults[keyPath: keyPath]
			let key = NSExpression(forKeyPath: keyPath).keyPath
			self.setValue(value, forKey: key)
			NSUbiquitousKeyValueStore.default.set(value, forKey: key)
#if DEBUG
			NSUbiquitousKeyValueStore.default.synchronize()
#endif
			apply?()
		})
	}

	@MainActor
	@objc private func didChangeExternally(notification: Notification) {
		let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
		for key in keys {
			setValue(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
		}
#if DEBUG
		synchronize()
#endif
	}
}
