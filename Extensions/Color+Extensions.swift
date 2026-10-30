import SwiftUI

extension Color {
	static let background = Self(UIColor.systemBackground)
	static let brand = Self(UIColor.tintColor)
	static let tertiary = Self(UIColor.tertiaryLabel)
	/// Song counts and other secondary text: dimmer like the system's secondary gray, but dark enough for 4.5:1 contrast at small sizes, which that gray isn't. Full strength with Increase Contrast.
	static let secondaryText = Self(UIColor { $0.accessibilityContrast == .high ? .label : .label.withAlphaComponent(0.62) })
}

extension UIColor {
	static let accentColor = UIColor(named: "AccentColor")!
}

/// A grouped list's section title, in the darker secondary color, since the system's gray falls short of 4.5:1 at that size
struct SectionTitle: View {
	let title: LocalizedStringKey

	init(_ title: LocalizedStringKey) {
		self.title = title
	}

	var body: some View {
		Text(title)
			.foregroundStyle(Color.secondaryText)
	}
}
