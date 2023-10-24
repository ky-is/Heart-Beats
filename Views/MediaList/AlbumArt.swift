import SwiftUI
import MediaPlayer

struct AlbumArt: View {
	let artwork: MPMediaItemArtwork?
	let displayWidth: CGFloat

	init(artwork: MPMediaItemArtwork?, displayWidth: CGFloat = 88) {
		self.artwork = artwork
		self.displayWidth = displayWidth
	}

	var body: some View {
		Group {
			if let image = artwork?.image(at: CGSize(width: displayWidth * 2, height: displayWidth * 2)) {
				Image(uiImage: image)
					.resizable()
//#if DEBUG
//					.blur(radius: SCREENSHOT_MODE ? 10 : 0) //SAMPLE
//#endif
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
			.clipShape(RoundedRectangle(cornerRadius: displayWidth / 6, style: .continuous))
			.shadow(color: .black.opacity(0.25), radius: 4, y: 3)
	}
}

#Preview {
	AlbumArt(artwork: MediaCollection.screenshotData[0].artwork)
}
