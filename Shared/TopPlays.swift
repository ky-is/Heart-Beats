import Foundation

/// What a play was of: one of the app's three lists.
nonisolated enum PlayKind: String, Codable, CaseIterable, Sendable {
	case artist, genre, year
}

/// The most played artists, genres and years with their covers, written by the app to the shared app group container and read by the widget.
nonisolated struct TopPlays: Codable, Sendable {
	struct Entry: Codable, Sendable, Hashable, Identifiable {
		let name: String
		let songCount: Int
		/// Times played from Heart Beats
		let plays: Int
		/// The cover's file name in `coversURL`
		let cover: String?
		/// The songs a tap plays, as library persistent IDs, so the widget can queue them without Heart Beats
		let songIDs: [UInt64]

		var id: String { name }
	}

	/// The most played, keyed by `PlayKind.rawValue`
	var entries: [String: [Entry]] = [:]
	/// Favorite artists and genres (years have none), keyed by `PlayKind.rawValue`
	var favorites: [String: [Entry]] = [:]
	/// Every name in each list, for Siri, Shortcuts and the control to pick from, keyed by `PlayKind.rawValue`
	var names: [String: [String]] = [:]

	func entries(for kind: PlayKind) -> [Entry] {
		entries[kind.rawValue] ?? []
	}

	func favorites(for kind: PlayKind) -> [Entry] {
		favorites[kind.rawValue] ?? []
	}

	func names(for kind: PlayKind) -> [String] {
		names[kind.rawValue] ?? []
	}

	/// The saved entry with this name, from the most played or favorites
	func entry(_ kind: PlayKind, named name: String) -> Entry? {
		(entries(for: kind) + favorites(for: kind)).first { $0.name == name }
	}

	/// The most the largest widget shows
	static let maximumCount = 9

	static let appGroup = "group.is.ky.Heart-Beats"

	static var containerURL: URL? {
		FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
	}

	static var fileURL: URL? {
		containerURL?.appending(path: "top-plays.json")
	}

	static var coversURL: URL? {
		containerURL?.appending(path: "Covers", directoryHint: .isDirectory)
	}

	static func load() -> TopPlays? {
		guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
		return try? JSONDecoder().decode(TopPlays.self, from: data)
	}

	/// Writes only when something changed, and says whether it did.
	@discardableResult
	func save() -> Bool {
		guard let url = Self.fileURL else { return false }
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		guard let data = try? encoder.encode(self) else { return false }
		if let existing = try? Data(contentsOf: url), existing == data {
			return false
		}
		return (try? data.write(to: url, options: .atomic)) != nil
	}
}
