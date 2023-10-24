import UserNotifications

struct StorageKey {
	static let played = "played"
	static let favorited = "favorited"
	static let combined = "combined"
	static let playedGenres = "playedGenres"
	static let favoritedGenres = "favoritedGenres"
	static let combinedGenres = "combinedGenres"
	static let showGenres = "showGenres"
	static let minimum = "minimum"
	static let cachedArtists = "cachedArtists"
	static let cachedGenres = "cachedGenres"

}

typealias CacheSong = (name: String, songCount: Int)

extension UserDefaults {
	@objc dynamic var played: [String] {
		array(forKey: StorageKey.played) as? [String] ?? []
	}
	@objc dynamic var playedGenres: [String] {
		array(forKey: StorageKey.playedGenres) as? [String] ?? []
	}
	@objc dynamic var favorited: [String] {
#if targetEnvironment(simulator)
		return ["Beach House", "Frédéric Chopin", "indigo la End", "Lost Frequencies", "Polo & Pan", "Stromae", "Sufjan Stevens", "Toe", "Yelle"]
#else
		return array(forKey: StorageKey.favorited) as? [String] ?? []
#endif
	}
	@objc dynamic var favoritedGenres: [String] {
#if targetEnvironment(simulator)
		return ["Classical", "Française", "Hip-Hop", "K-Pop", "J-Rock", "Post-Rock", "Reggae"]
#else
		return array(forKey: StorageKey.favoritedGenres) as? [String] ?? []
#endif
	}
	@objc dynamic var combined: [[String]] {
		array(forKey: StorageKey.combined) as? [[String]] ?? []
	}
	@objc dynamic var combinedGenres: [[String]] {
		array(forKey: StorageKey.combinedGenres) as? [[String]] ?? []
	}
	@objc dynamic var showGenres: Bool {
		bool(forKey: StorageKey.showGenres)
	}
	@objc dynamic var minimum: Int {
#if targetEnvironment(simulator)
		return 15
#else
		let stored = integer(forKey: StorageKey.minimum)
		return stored <= 0 ? 15 : stored
#endif
	}

	var cachedArtists: [[Any]]? {
		get {
			return array(forKey: StorageKey.cachedArtists) as? [[Any]]
		}
		set(value) {
			set(value, forKey: StorageKey.cachedArtists)
		}
	}
	var cachedGenres: [[Any]]? {
		get {
			return array(forKey: StorageKey.cachedGenres) as? [[Any]]
		}
		set(value) {
			set(value, forKey: StorageKey.cachedGenres)
		}
	}
}

final class SyncStorage: ObservableObject {
	static let shared = SyncStorage()

	@Published var played: [String] {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.played)
		}
	}
	@Published var favorited: [String] {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.favorited)
		}
	}
	@Published var combined: [[String]] {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.combined)
		}
	}
	@Published var playedGenres: [String] {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.playedGenres)
		}
	}
	@Published var favoritedGenres: [String] {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.favoritedGenres)
		}
	}
	@Published var combinedGenres: [[String]] {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.combinedGenres)
		}
	}
	@Published var showGenres: Bool {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.showGenres)
		}
	}
	@Published var minimum: Int {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.minimum)
		}
	}
	@Published var cachedArtists: [[Any]]? {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.cachedArtists)
		}
	}
	@Published var cachedGenres: [[Any]]? {
		willSet {
			UserDefaults.standard.set(newValue, forKey: StorageKey.cachedGenres)
		}
	}

	var currentPlayed: [String] {
		showGenres ? playedGenres : played
	}

	var currentFavorites: [String] {
		return showGenres ? favoritedGenres : favorited
	}

	var currentCombined: [[String]] {
		showGenres ? combinedGenres : combined
	}

	private var observers: [NSKeyValueObservation] = []

	private init() {
		played = UserDefaults.standard.played
		favorited = UserDefaults.standard.favorited
		combined = UserDefaults.standard.combined
		playedGenres = UserDefaults.standard.playedGenres
		favoritedGenres = UserDefaults.standard.favoritedGenres
		combinedGenres = UserDefaults.standard.combinedGenres
		showGenres = UserDefaults.standard.showGenres
		minimum = UserDefaults.standard.minimum
		cachedArtists = UserDefaults.standard.cachedArtists
		cachedGenres = UserDefaults.standard.cachedGenres

		NotificationCenter.default.addObserver(self, selector: #selector(didChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)

		observers.append(UserDefaults.standard.observe(\.played) { (defaults, change) in
			Task { @MainActor in
				self.played = UserDefaults.standard.played
				NSUbiquitousKeyValueStore.default.set(self.played, forKey: StorageKey.played)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.favorited) { (defaults, change) in
			Task { @MainActor in
				self.favorited = UserDefaults.standard.favorited
				NSUbiquitousKeyValueStore.default.set(self.favorited, forKey: StorageKey.favorited)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.combined) { (defaults, change) in
			Task { @MainActor in
				self.combined = UserDefaults.standard.combined
				NSUbiquitousKeyValueStore.default.set(self.combined, forKey: StorageKey.combined)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.playedGenres) { (defaults, change) in
			Task { @MainActor in
				self.playedGenres = UserDefaults.standard.playedGenres
				NSUbiquitousKeyValueStore.default.set(self.playedGenres, forKey: StorageKey.playedGenres)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.favoritedGenres) { (defaults, change) in
			Task { @MainActor in
				self.favoritedGenres = UserDefaults.standard.favoritedGenres
				NSUbiquitousKeyValueStore.default.set(self.favoritedGenres, forKey: StorageKey.favoritedGenres)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.combinedGenres) { (defaults, change) in
			Task { @MainActor in
				self.combinedGenres = UserDefaults.standard.combinedGenres
				NSUbiquitousKeyValueStore.default.set(self.combinedGenres, forKey: StorageKey.combinedGenres)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.showGenres) { (defaults, change) in
			Task { @MainActor in
				self.showGenres = UserDefaults.standard.showGenres
				MediaCollection.updateCurrent()
				NSUbiquitousKeyValueStore.default.set(self.showGenres, forKey: StorageKey.showGenres)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
		observers.append(UserDefaults.standard.observe(\.minimum) { (defaults, change) in
			Task { @MainActor in
				self.minimum = UserDefaults.standard.minimum
				MediaCollection.updateCurrent()
				NSUbiquitousKeyValueStore.default.set(self.minimum, forKey: StorageKey.minimum)
				#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
				#endif
			}
		})
	}

	@objc private func didChangeExternally(notification: Notification) {
		let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
		Task { @MainActor in
			for key in keys {
				switch key {
				case StorageKey.played:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
				case StorageKey.favorited:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
				case StorageKey.combined:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
				case StorageKey.playedGenres:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
				case StorageKey.favoritedGenres:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
				case StorageKey.combinedGenres:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
				case StorageKey.showGenres:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.bool(forKey: key), forKey: key)
				case StorageKey.minimum:
					UserDefaults.standard.set(NSUbiquitousKeyValueStore.default.longLong(forKey: key), forKey: key)
				case "SyncKey": //TODO remove now unused
					UserDefaults.standard.removeObject(forKey: "SyncKey")
				default:
					print("UNKNOWN EXTERNAL KEY", key)
				}
			}
			#if DEBUG
			UserDefaults.standard.synchronize()
			#endif
		}
	}
}
