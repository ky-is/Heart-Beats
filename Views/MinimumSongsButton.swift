import SwiftUI

struct MinimumSongsButton: View {
	var geometry: GeometryProxy?

	@State private var showSongMinimum = false

	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum

	var body: some View {
		Button {
			showSongMinimum = true
		} label: {
			Text(String(minimum))
				.font(.system(size: 24, weight: .bold))
				.frame(width: 64, height: 64)
//				.background(Color.red)
		}
			.popover(isPresented: $showSongMinimum) {
				MinimumSongsStepper()
			}
	}
}

struct MinimumSongsStepper: View {
	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum

	var body: some View {
		HStack {
			Text("Minimum number of songs an artist/genre needs to be displayed:")
				.fixedSize(horizontal: false, vertical: true)
				.font(.footnote)
				.padding([.leading, .vertical])
			Button {
				minimum -= 1
			} label: {
				Image(systemName: "minus")
					.frame(width: 40, height: 40)
					.bold()
			}
				.disabled(minimum <= 0)
			Button {
				minimum += 1
			} label: {
				Image(systemName: "plus")
					.frame(width: 40, height: 40)
					.bold()
			}
				.disabled(minimum >= GroupedCollection.current.maximumSongsLimit)
		}
			.imageScale(.large)
			.presentationCompactAdaptation(.popover)
#if targetEnvironment(macCatalyst)
			.padding(.horizontal)
#endif
	}
}

#Preview {
	GeometryReader { geometry in
		MinimumSongsButton(geometry: geometry)
			.popover(isPresented: .constant(true)) {
				MinimumSongsStepper()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
		.fontDesign(.rounded)
}
