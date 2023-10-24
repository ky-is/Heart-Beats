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
		var image = artwork?.image(at: CGSize(width: displayWidth * 2, height: displayWidth * 2))
#if DEBUG
		if image == nil {
			image = UIImage(named: "\(artist).jpeg")
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

#Preview {
	let entry = MediaCollection.screenshotData[0]
	return AlbumArt(artist: entry.id, artwork: entry.artwork, displayWidth: 88 * 2)
}
