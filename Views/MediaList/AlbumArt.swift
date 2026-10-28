import SwiftUI
import MediaPlayer

struct AlbumArt: View {
	let artist: String
	let artwork: MPMediaItemArtwork?
	let displayWidth: CGFloat

	init(artist: String, artwork: MPMediaItemArtwork?, displayWidth: CGFloat = 88) {
		self.artist = artist
		self.artwork = artwork
		self.displayWidth = displayWidth
	}

	var uiImage: UIImage? {
		let image = artwork.flatMap { ArtworkCache.image(for: $0, size: displayWidth * 2) }
#if targetEnvironment(simulator)
		if image == nil {
			return UIImage(named: "\(artist).jpeg")
		}
#endif
		return image
	}

	var body: some View {
		Group {
			if let uiImage {
				Image(uiImage: uiImage)
					.resizable()
#if targetEnvironment(simulator)
//					.blur(radius: 10) //SAMPLE
#endif
			} else {
				Image(systemName: "music.note.list")
					.resizable()
					.padding()
					.foregroundStyle(Color.background)
					.font(.system(size: displayWidth * (2 / 3)))
					.background(in: Rectangle())
					.backgroundStyle(Color.tertiary)
					.unredacted()
			}
		}
			.frame(width: displayWidth, height: displayWidth)
			.clipShape(RoundedRectangle(cornerRadius: min(24, displayWidth / 6), style: .continuous))
			.shadow(color: .black.opacity(0.25), radius: 4, y: 3)
	}
}

/// Decoded artwork, so redraws and scrolling don't decode it again.
enum ArtworkCache {
	// Holding the artwork keeps its address from being reused by another artwork while cached
	private final class Item {
		let artwork: MPMediaItemArtwork
		let image: UIImage?

		init(artwork: MPMediaItemArtwork, image: UIImage?) {
			self.artwork = artwork
			self.image = image
		}
	}

	private static let cache: NSCache<NSString, Item> = {
		let cache = NSCache<NSString, Item>()
		cache.countLimit = 500
		return cache
	}()

	static func image(for artwork: MPMediaItemArtwork, size: CGFloat) -> UIImage? {
		let key = "\(ObjectIdentifier(artwork).hashValue)-\(Int(size))" as NSString
		if let item = cache.object(forKey: key), item.artwork === artwork {
			return item.image
		}
		let image = artwork.image(at: CGSize(width: size, height: size))
		cache.setObject(Item(artwork: artwork, image: image), forKey: key)
		return image
	}
}

#Preview {
	let entry = GroupedCollection.screenshotData[0]
	return AlbumArt(artist: entry.id, artwork: entry.artwork, displayWidth: 88 * 2)
}
