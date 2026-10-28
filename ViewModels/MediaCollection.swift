import MediaPlayer
import Observation
import SwiftUI

// Built off the main thread by the library scans. MediaPlayer items and artwork aren't marked Sendable, but they're read-only snapshots of the library.
nonisolated struct MediaEntry: @unchecked Sendable, Identifiable, Hashable {
	let id: String
	let songs: [MPMediaItem]?
	let songCount: Int
	let artwork: MPMediaItemArtwork?

	// Skips comparing every song, which List selection would otherwise do on each check
	static func == (lhs: Self, rhs: Self) -> Bool {
		// Cached entries have no songs, so a loaded entry never equals its cached placeholder
		lhs.id == rhs.id && lhs.songCount == rhs.songCount && lhs.artwork === rhs.artwork && (lhs.songs == nil) == (rhs.songs == nil)
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}

protocol MediaCollection {
	var entries: [MediaEntry] { get set }

	static var screenshotData: [MediaEntry] { get }

	@concurrent func update(withAnimation animated: Bool) async
}
