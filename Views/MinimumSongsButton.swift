import SwiftUI

/// The minimum actually applied: the stored one, capped to the current library's largest entry.
private func effectiveMinimum(_ minimum: Int, selectedTab: String) -> Int {
	let collection = selectedTab == "genres" ? GroupedCollection.genres : GroupedCollection.artists
	return min(minimum, collection.maximumSongsLimit)
}

struct MinimumSongsButton: View {
	@State private var showSongMinimum = false

	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	var body: some View {
		let value = effectiveMinimum(minimum, selectedTab: selectedTab)
		Button {
			showSongMinimum = true
		} label: {
			Text(String(value))
				.font(.system(size: 24, weight: .bold))
				.frame(width: 64, height: 64)
		}
			.accessibilityLabel("Minimum songs")
			.accessibilityValue(String(value))
			.popover(isPresented: $showSongMinimum) {
				MinimumSongsStepper()
			}
	}
}

struct MinimumSongsStepper: View {
	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	var body: some View {
		let collection = selectedTab == "genres" ? GroupedCollection.genres : GroupedCollection.artists
		let value = effectiveMinimum(minimum, selectedTab: selectedTab)
		HStack {
			Text("Minimum number of songs an artist/genre needs to be displayed:")
				.fixedSize(horizontal: false, vertical: true)
				.font(.footnote)
				.padding([.leading, .vertical])
			// Steps from the applied value, so a stored minimum above the library's largest entry doesn't make taps look ignored
			Button("Fewer songs", systemImage: "minus") {
				minimum = value - 1
			}
				.labelStyle(.iconOnly)
				.frame(width: 40, height: 40)
				.bold()
				// 0 isn't a valid minimum: the stored value treats it as unset (15)
				.disabled(value <= 1)
			Button("More songs", systemImage: "plus") {
				minimum = value + 1
			}
				.labelStyle(.iconOnly)
				.frame(width: 40, height: 40)
				.bold()
				.disabled(value >= collection.maximumSongsLimit)
		}
			.imageScale(.large)
			.presentationCompactAdaptation(.popover)
#if targetEnvironment(macCatalyst)
			.padding(.horizontal)
#endif
	}
}

#Preview {
	MinimumSongsButton()
		.popover(isPresented: .constant(true)) {
			MinimumSongsStepper()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.fontDesign(.rounded)
}
