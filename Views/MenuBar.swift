#if targetEnvironment(macCatalyst)
import MediaPlayer
import os
import UIKit

/// The Mac menu bar item (a popover), an AppKit bundle (MenuBar/) loaded at launch since Mac Catalyst can't make one itself. It keeps the item in the menu bar after the window is closed, so this plays from the collections rather than from any view. The two sides share no code, only notifications with property list payloads.
enum MenuBar {
	private static let updateName = Notification.Name("is.ky.Heart-Beats.menuBar.update")
	private static let playName = Notification.Name("is.ky.Heart-Beats.menuBar.play")
	private static let openName = Notification.Name("is.ky.Heart-Beats.menuBar.open")
	private static let coversName = Notification.Name("is.ky.Heart-Beats.menuBar.covers")
	/// The covers' size in pixels: 32 pt rows at 2x
	private static let coverPixels = AlbumArt.pixelSize(forWidth: 32)

	private static var plugin: NSObject?
	/// The covers already sent, by album
	private static var sentCovers: Set<String> = []

	static func start() {
		guard plugin == nil, let url = Bundle.main.builtInPlugInsURL?.appending(path: "Heart Beats Menu Bar.bundle"), let bundle = Bundle(url: url) else {
			log.error("The menu bar item isn't in the app")
			return
		}
		do {
			try bundle.loadAndReturnError()
		} catch {
			// The bundle's own error says nothing; the loader's does
			let executable = bundle.executablePath ?? ""
			_ = unsafe dlopen(executable, RTLD_NOW)
			let reason = unsafe dlerror().map { unsafe String(cString: $0) } ?? error.localizedDescription
			log.error("Couldn't load the menu bar item: \(reason, privacy: .public)")
			return
		}
		guard let pluginClass = bundle.principalClass as? NSObject.Type else {
			log.error("The menu bar item has no principal class")
			return
		}
		plugin = pluginClass.init()
		NotificationCenter.default.addObserver(forName: playName, object: nil, queue: .main) { note in
			let tab = note.userInfo?["tab"] as? String
			let name = note.userInfo?["name"] as? String
			MainActor.assumeIsolated {
				if let tab, let name {
					play(name, in: tab)
				}
			}
		}
		NotificationCenter.default.addObserver(forName: openName, object: nil, queue: .main) { _ in
			MainActor.assumeIsolated {
				openWindow()
			}
		}
		publishLists()
#if DEBUG
		debugCloseAndReopenIfAsked()
#endif
	}

	/// Sends the lists again whenever either grouping or the years change, including while no window is open.
	private static func publishLists() {
		Task {
			let lists = Observations {
				let artists = GroupedCollection.artists.sections
				let genres = GroupedCollection.genres.sections
				return [
					MenuBarList(tab: "artists", favorites: artists.first { $0.label == FavoritesLabel }?.entries ?? [], others: artists.first { $0.label != FavoritesLabel }?.entries ?? []),
					MenuBarList(tab: "genres", favorites: genres.first { $0.label == FavoritesLabel }?.entries ?? [], others: genres.first { $0.label != FavoritesLabel }?.entries ?? []),
					MenuBarList(tab: "years", favorites: [], others: YearsCollection.shared.entries),
				]
			}
			var sent: [MenuBarList]?
			for await lists in lists where lists != sent {
				sent = lists
				NotificationCenter.default.post(name: updateName, object: nil, userInfo: ["lists": lists.map(\.propertyList)])
				sendCovers(for: lists)
			}
		}
	}

	/// Decodes the covers the lists show that the menu bar doesn't have yet and sends them, keyed by album, a batch at a time so they fill in as they come. A list names its covers, so a new list doesn't send images again.
	private static func sendCovers(for lists: [MenuBarList]) {
		let new = Dictionary(lists.flatMap(\.items).compactMap(\.artwork).filter { !sentCovers.contains($0.id) }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		guard !new.isEmpty else { return }
		sentCovers.formUnion(new.keys)
		Task {
			var covers: [String: Data] = [:]
			for (id, artwork) in new {
				if let image = await ArtworkCache.image(for: artwork, size: coverPixels), let data = image.jpegData(compressionQuality: 0.8) {
					covers[id] = data
				}
				if covers.count >= 40 {
					post(covers)
					covers = [:]
				}
			}
			post(covers)
		}
	}

	private static func post(_ covers: [String: Data]) {
		guard !covers.isEmpty else { return }
		NotificationCenter.default.post(name: coversName, object: nil, userInfo: ["covers": covers])
	}

	/// Plays an entry like a tap in its list does. The lists load from a cache at launch, whose entries have no songs until the first scan finishes, so it waits for them.
	private static func play(_ name: String, in tab: String) {
		let kind: PlayKind = tab == "genres" ? .genre : tab == "years" ? .year : .artist
		Task {
			for _ in 0..<150 {
				let entries = switch kind {
				case .artist: GroupedCollection.artists.entries
				case .genre: GroupedCollection.genres.entries
				case .year: YearsCollection.shared.entries
				}
				if let songs = entries.first(where: { $0.id.normalized() == name.normalized() })?.songs {
					recordPlay(of: name, kind: kind)
					playSongs(songs, addToQueue: false)
					return
				}
				try? await Task.sleep(for: .milliseconds(200))
			}
			log.error("Songs for \(name, privacy: .private) didn't load")
		}
	}

	/// Brings the window forward, or opens a new one when it was closed.
	private static func openWindow() {
		let application = UIApplication.shared
		application.requestSceneSessionActivation(application.openSessions.first, userActivity: nil, options: nil) { error in
			log.error("Couldn't open the window: \(error.localizedDescription, privacy: .public)")
		}
	}

#if DEBUG
	/// Mac checks: -debugCloseWindow 4 closes every window after that many seconds, and -debugReopenWindow 10 opens one again, as the menu's Open item does, without any input events
	private static func debugCloseAndReopenIfAsked() {
		let defaults = UserDefaults.standard
		if let seconds = Double(defaults.string(forKey: "debugCloseWindow") ?? "") {
			Task {
				try? await Task.sleep(for: .seconds(seconds))
				for session in UIApplication.shared.openSessions {
					UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
				}
			}
		}
		// -debugShowMenuBar 8 opens the popover that many seconds in, as a click on the item does
		if let seconds = Double(defaults.string(forKey: "debugShowMenuBar") ?? "") {
			Task {
				try? await Task.sleep(for: .seconds(seconds))
				_ = unsafe plugin?.perform(NSSelectorFromString("statusItemClicked"))
			}
		}
		if let seconds = Double(defaults.string(forKey: "debugReopenWindow") ?? "") {
			Task {
				try? await Task.sleep(for: .seconds(seconds))
				// The menu's Open item
				_ = unsafe plugin?.perform(NSSelectorFromString("openApp"))
			}
		}
	}
#endif
}
#endif
