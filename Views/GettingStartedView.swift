import SwiftUI

/// What Getting Started knows about the library, from the last scan
struct GettingStarted: Equatable {
	/// How many songs count toward the lists so far
	let topRatedCount: Int?
	/// How many played songs don't count yet, which Favorite Songs would suggest
	let suggestionCount: Int?

	/// Played songs to favorite here, so that's the first thing to try. Otherwise there's too little to suggest, and Music is the place to find songs.
	var canSuggest: Bool {
		(suggestionCount ?? 0) >= AppleMusicFavorites.enoughSuggestions
	}
}

/// Explains where the lists come from and how to grow them: favorite your most played songs here when there are enough of them, or favorite songs in Music. Tops the lists while the library has too few songs for them to work well, and fills the screen when it has none.
struct GettingStartedCard: View {
	let state: GettingStarted

	@Environment(\.openURL) private var openURL
	@Environment(\.showFavoriteSongs) private var showFavoriteSongs

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 8) {
				Image(systemName: "heart.text.square.fill")
					.font(.system(size: 44))
					.foregroundStyle(.tint)
					.accessibilityHidden(true)
				Text("Grow Your Playlists")
					.font(.title2.bold())
					.accessibilityAddTraits(.isHeader)
				Text("Heart Beats shuffles your favorite songs, grouped by artist and genre. The more songs you favorite, the more artists and genres show up. Songs rated 5 stars count too.")
					.foregroundStyle(Color.secondaryText)
				if let topRatedCount = state.topRatedCount {
					Text(topRatedCount == 1 ? "So far, 1 song counts." : "So far, \(topRatedCount) songs count.")
						.font(.headline)
				}
			}
				.accessibilityElement(children: .combine)
			if state.canSuggest {
				VStack(spacing: 8) {
					// A button rather than a link, since a link in a list row takes over the whole row
					Button {
						showFavoriteSongs()
					} label: {
						Text("Favorite Your Most Played")
							.font(.headline)
							.frame(maxWidth: .infinity)
					}
						.buttonStyle(.glassProminent)
						.controlSize(.extraLarge)
					Caption("Pick from the songs you play most, right here.")
				}
				Button {
					openMusic()
				} label: {
					Text("Find Songs in Music")
						.frame(maxWidth: .infinity)
				}
					.buttonStyle(.glass)
					.controlSize(.large)
					.accessibilityHint("Opens the Music app, where you can favorite songs")
			} else {
				VStack(spacing: 8) {
					Button {
						openMusic()
					} label: {
						Text("Open Music")
							.font(.headline)
							.frame(maxWidth: .infinity)
					}
						.buttonStyle(.glassProminent)
						.controlSize(.extraLarge)
						.accessibilityHint("Opens the Music app, where you can favorite songs")
					Caption("Find songs you love in Apple Music and tap the star to favorite them.")
				}
			}
		}
			.padding(20)
			.frame(maxWidth: 560, alignment: .leading)
			.background(.background.secondary, in: .rect(cornerRadius: 28))
			.frame(maxWidth: .infinity)
	}

	private func openMusic() {
		openURL(.musicApp)
	}
}

private struct Caption: View {
	let text: LocalizedStringKey

	init(_ text: LocalizedStringKey) {
		self.text = text
	}

	var body: some View {
		Text(text)
			.font(.subheadline)
			.foregroundStyle(Color.secondaryText)
			.frame(maxWidth: .infinity)
			.multilineTextAlignment(.center)
			.accessibilityHidden(true)
	}
}

/// Getting Started on its own page, from Settings
struct GettingStartedPage: View {
	var body: some View {
		ScrollView {
			GettingStartedCard(state: GroupedCollection.artists.gettingStartedState)
				.padding()
		}
			.navigationTitle("Getting Started")
			.opensFavoriteSongs()
	}
}

extension EnvironmentValues {
	/// Opens Favorite Songs from Getting Started, which can sit in a lazy list where a navigation destination is ignored
	@Entry var showFavoriteSongs: () -> Void = {}
}

extension View {
	/// Lets Getting Started inside this view open Favorite Songs. Goes outside any list, where navigation destinations work.
	func opensFavoriteSongs() -> some View {
		modifier(OpensFavoriteSongs())
	}
}

private struct OpensFavoriteSongs: ViewModifier {
	@State private var isShowing = false

	func body(content: Content) -> some View {
		content
			.environment(\.showFavoriteSongs) { isShowing = true }
			.navigationDestination(isPresented: $isShowing) {
				FavoriteSongsView()
			}
	}
}

#Preview {
	NavigationStack {
		GettingStartedPage()
	}
		.fontDesign(.rounded)
}
