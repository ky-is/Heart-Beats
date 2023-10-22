import SwiftUI

struct MinimumSongsButton: View {
	var geometry: GeometryProxy

	@State private var showSongMinimum = false
	@EnvironmentObject private var syncStorage: SyncStorage

	var body: some View {
		Button {
			showSongMinimum = true
		} label: {
			ZStack {
				Circle()
					.frame(width: 40, height: 40)
					.foregroundStyle(.accent).opacity(0.75)
				Text(String(syncStorage.minimum))
					.font(.system(size: 24, weight: .bold))
					.foregroundStyle(.black)
					.blendMode(.destinationOut)
			}
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

struct MinimumSongsStepper: View {
	@EnvironmentObject private var syncStorage: SyncStorage

	var body: some View {
		HStack {
			Button {
				syncStorage.minimum -= 1
			} label: {
				Image(systemName: "chevron.left")
					.frame(minWidth: 44, maxHeight: .infinity)
			}
				.disabled(syncStorage.minimum <= 0)
			Text("Minimum number of songs an artist/genre needs to be displayed")
				.fixedSize(horizontal: false, vertical: true)
				.multilineTextAlignment(.center)
				.font(.footnote)
				.padding(.vertical, 32)
			Button {
				syncStorage.minimum += 1
			} label: {
				Image(systemName: "chevron.right")
					.frame(minWidth: 44, maxHeight: .infinity)
			}
				.disabled(syncStorage.minimum >= MediaCollection.current.maximumSongsLimit)
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
		.environmentObject(SyncStorage.shared)
}
