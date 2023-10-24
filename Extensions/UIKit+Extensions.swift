import UIKit

extension UIFont {
	class func rounded(style: TextStyle, bold: Bool) -> UIFont {
		let font = UIFont.preferredFont(forTextStyle: style)
		var descriptor = font.fontDescriptor.withDesign(.rounded)!
		if bold {
			descriptor = descriptor.withSymbolicTraits(.traitBold)!
		}
		return UIFont(descriptor: descriptor, size: font.pointSize)
	}
}

extension UIImage {
	func scale(to targetSize: CGSize) -> UIImage {
		let widthRatio = targetSize.width / size.width
		let heightRatio = targetSize.height / size.height
		let scaleFactor = min(widthRatio, heightRatio)
		let scaledImageSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
		let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
		let scaledImage = renderer.image { _ in
			self.draw(in: CGRect(origin: .zero, size: scaledImageSize))
		}
		return scaledImage
	}
}
