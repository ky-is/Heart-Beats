import SwiftUI

struct MinimumSongsButton: View {
	var geometry: GeometryProxy

	@State private var showSongMinimum = false

	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum

	var body: some View {
		Button {
			showSongMinimum = true
		} label: {
			Text(String(minimum))
				.font(.system(size: 24, weight: .bold))
				.foregroundStyle(.black)
				.blendMode(.destinationOut)
				.frame(width: 40, height: 40)
				.background(in: Circle())
				.backgroundStyle(.accent.opacity(0.75))
				.compositingGroup()
				.padding(.bottom, geometry.safeAreaInsets.bottom > 5 ? 0 : 5)
				.padding(.horizontal, 12)
				.padding(.top, 8)
		}
			.popover(isPresented: $showSongMinimum) {
				MinimumSongsStepper()
			}
	}
}

private struct MinimumSongsStepper: View {
	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum

	var body: some View {
		HStack {
			Button {
				minimum -= 1
			} label: {
				Image(systemName: "minus")
					.frame(minWidth: 44, maxHeight: .infinity)
					.bold()
			}
				.disabled(minimum <= 0)
			Text("Minimum number of songs an artist/genre needs to be displayed")
				.fixedSize(horizontal: false, vertical: true)
				.multilineTextAlignment(.center)
				.font(.footnote)
				.padding(.vertical, 32)
			Button {
				minimum += 1
			} label: {
				Image(systemName: "plus")
					.frame(minWidth: 44, maxHeight: .infinity)
					.bold()
			}
				.disabled(minimum >= MediaCollection.current.maximumSongsLimit)
		}
			.imageScale(.large)
			.presentationCompactAdaptation(.popover)
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
		.tint(.accent)
}
