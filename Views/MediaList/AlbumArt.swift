import SwiftUI
import MediaPlayer
import os

struct AlbumArt: View {
	let artist: String
	let artwork: ArtworkCache.Artwork?
	let displayWidth: CGFloat

	init(artist: String, artwork: ArtworkCache.Artwork?, displayWidth: CGFloat = AlbumArt.listWidth) {
		self.artist = artist
		self.artwork = artwork
		self.displayWidth = displayWidth
	}

	/// The size in the list layout, which scans decode ahead of time.
	static let listWidth: CGFloat = 88

	static func pixelSize(forWidth width: CGFloat) -> CGFloat {
		width * 2
	}

	/// The image decoded off the main thread for this artwork and size
	@State private var loaded: (key: String, image: UIImage?)?

	private var pixelSize: CGFloat {
		Self.pixelSize(forWidth: displayWidth)
	}

	private var key: String? {
		artwork.map { ArtworkCache.key(for: $0, size: pixelSize) }
	}

	private var uiImage: UIImage? {
		var image: UIImage?
		if let artwork {
			if let loaded, loaded.key == key {
				image = loaded.image
			} else {
				// Already decoded by a scan or another row, so it shows on the first frame
				image = ArtworkCache.cachedImage(for: artwork, size: pixelSize)
			}
		}
		if image == nil && SampleLibrary.isOn {
			return UIImage(named: "\(artist).jpeg")
		}
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
			.task(id: key) {
				guard let artwork, let key else { return }
				if let cached = ArtworkCache.cachedImage(for: artwork, size: pixelSize) {
					loaded = (key, cached)
					return
				}
				let image = await ArtworkCache.image(for: artwork, size: pixelSize)
				guard !Task.isCancelled else { return }
				loaded = (key, image)
			}
	}
}

/// Decoded artwork, so redraws, scrolling and rescans don't decode it again. Decoding happens off the main thread.
nonisolated enum ArtworkCache {
	/// Artwork with a stable ID: rescans return new artwork objects, but an album keeps its ID. MediaPlayer artwork isn't marked Sendable, but it's a read-only snapshot of the library.
	struct Artwork: @unchecked Sendable, Hashable {
		let value: MPMediaItemArtwork
		let id: String

		init(_ value: MPMediaItemArtwork, id: MPMediaEntityPersistentID?) {
			self.value = value
			// Without an ID, the object is the only identity it has
			self.id = id.map { "\($0)" } ?? "object-\(ObjectIdentifier(value).hashValue)"
		}

		init?(song: MPMediaItem) {
			guard let artwork = song.artwork else { return nil }
			self.init(artwork, id: song.artworkID)
		}

		static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.id == rhs.id
		}

		func hash(into hasher: inout Hasher) {
			hasher.combine(id)
		}
	}

	// Wrapped so a failed decode is cached too
	private final class Item {
		let image: UIImage?

		init(image: UIImage?) {
			self.image = image
		}
	}

	// NSCache is thread-safe, though it isn't marked Sendable
	private final class Store: @unchecked Sendable {
		let cache: NSCache<NSString, Item> = {
			let cache = NSCache<NSString, Item>()
			// Decoded bitmaps, which the system also trims under memory pressure
			cache.totalCostLimit = 48 * 1024 * 1024
			return cache
		}()
	}

	private static let store = Store()

	static func key(for artwork: Artwork, size: CGFloat) -> String {
		"\(artwork.id)-\(Int(size))"
	}

	/// Frees every decoded image under memory pressure.
	static func removeAll() {
		store.cache.removeAllObjects()
	}

	/// The image if it's already decoded; never decodes.
	static func cachedImage(for artwork: Artwork, size: CGFloat) -> UIImage? {
		store.cache.object(forKey: key(for: artwork, size: size) as NSString)?.image
	}

	/// Decodes on the MediaPlayer queue, unless the row asking scrolled away first.
	static func image(for artwork: Artwork, size: CGFloat) async -> UIImage? {
		guard !Task.isCancelled else { return nil }
		return await MediaPlayerQueue.runArtwork {
			decodedImage(for: artwork, size: size)
		}
	}

	/// Decodes on the calling thread, which must be a MediaPlayer queue: decoding blocks while it waits on the music library.
	private static func decodedImage(for artwork: Artwork, size: CGFloat) -> UIImage? {
		let key = key(for: artwork, size: size) as NSString
		if let item = store.cache.object(forKey: key) {
			return item.image
		}
		let prepared: UIImage? = signposter.withIntervalSignpost("Decode artwork", id: signposter.makeSignpostID()) {
			// Often the full-size cover, whatever size is asked for
			guard let image = artwork.value.image(at: CGSize(width: size, height: size)) else { return nil }
			// Drawing at the target size decodes now rather than on the main thread, and keeps only the small bitmap. preparingForDisplay() can hang forever on background threads.
			let format = UIGraphicsImageRendererFormat()
			format.scale = 1
			format.opaque = true
			let side = size
			return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
				let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
				let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
				image.draw(in: CGRect(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2, width: drawSize.width, height: drawSize.height))
			}
		}
		let bytes = prepared?.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
		store.cache.setObject(Item(image: prepared), forKey: key, cost: bytes)
		return prepared
	}

	/// One cover per album, up to `count`, for the Years grid.
	static func albumImages(for entry: MediaEntry, size: CGFloat, count: Int) async -> [UIImage] {
		guard !Task.isCancelled else { return [] }
		return await MediaPlayerQueue.runArtwork {
			albumImagesNow(for: entry, size: size, count: count)
		}
	}

	private static func albumImagesNow(for entry: MediaEntry, size: CGFloat, count: Int) -> [UIImage] {
		var images: [UIImage] = []
		var albumIDs = Set<MPMediaEntityPersistentID>()
		for song in entry.songs ?? [] {
			let albumID = song.artworkID
			guard !albumIDs.contains(albumID), let artwork = Artwork(song: song), let image = decodedImage(for: artwork, size: size) else { continue }
			albumIDs.insert(albumID)
			images.append(image)
			if images.count >= count {
				break
			}
		}
		return images
	}
}

#Preview {
	let entry = MediaEntry.screenshotData[0]
	return AlbumArt(artist: entry.id, artwork: entry.albumArtwork, displayWidth: 88 * 2)
}
