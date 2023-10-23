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
