import MediaPlayer
import Observation
import SwiftUI

struct MediaEntry: Sendable, Identifiable, Hashable {
	let id: String
	let songs: [MPMediaItem]?
	let songCount: Int
	let artwork: MPMediaItemArtwork?
}

protocol MediaCollection {
	var entries: [MediaEntry] { get set }

	static var screenshotData: [MediaEntry] { get }

	@concurrent func update(withAnimation animated: Bool) async
}
