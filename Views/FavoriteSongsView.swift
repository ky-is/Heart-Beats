import MediaPlayer
import os
import SwiftUI

/// The most played songs that don't count yet, each with a button to favorite it in Apple Music.
struct FavoriteSongsView: View {
	@State private var availability: AppleMusicFavorites.Availability?
	@State private var suggestions: [FavoriteSuggestion]?
	@State private var favorited: Set<MPMediaEntityPersistentID> = []
	@State private var pending: Set<MPMediaEntityPersistentID> = []
	@State private var failed: FavoriteSuggestion?

	var body: some View {
		Group {
			switch availability {
			case nil:
				ProgressView()
			case .needsSyncLibrary:
				ContentUnavailableView {
					Label("Turn On Sync Library", systemImage: "icloud.slash")
				} description: {
					Text(Self.syncLibraryHelp)
				} actions: {
					Link(destination: Self.syncLibraryLink) {
						Text(Self.syncLibraryButton)
							.font(.headline)
							.padding(.horizontal, 24)
					}
						.buttonStyle(.glassProminent)
						.controlSize(.extraLarge)
				}
			case .unavailable:
				ContentUnavailableView {
					Label("Favorite in Music", systemImage: "heart.slash")
				} description: {
					Text("Heart Beats can't reach Apple Music right now. Favorite songs in the Music app instead.")
				} actions: {
					Link(destination: .musicApp) {
						Text("Open Music")
							.font(.headline)
							.padding(.horizontal, 24)
					}
						.buttonStyle(.glassProminent)
						.controlSize(.extraLarge)
				}
			case .available:
				if let suggestions {
					if suggestions.isEmpty {
						ContentUnavailableView("No Suggestions", systemImage: "music.note", description: Text("Your most played Apple Music songs are all favorited already."))
					} else {
						list(suggestions)
					}
				} else {
					ProgressView()
				}
			}
		}
			.navigationTitle("Favorite Songs")
			.task {
				let availability = await AppleMusicFavorites.availability()
				if availability == .available {
					suggestions = await AppleMusicFavorites.suggestions()
				}
				self.availability = availability
			}
			.alert("Couldn't Favorite", isPresented: Binding { failed != nil } set: { if !$0 { failed = nil } }, presenting: failed) { _ in
				Button("OK", role: .cancel) {}
			} message: { suggestion in
				Text("“\(suggestion.title)” couldn't be favorited. Check your connection, or favorite it in the Music app.")
			}
	}

#if targetEnvironment(macCatalyst)
	// The Mac has no link to Music's settings, so this opens Music itself
	private static let syncLibraryHelp: LocalizedStringKey = "Favorites sync through iCloud. Turn on Sync Library in Music > Settings > General, or favorite songs in Music instead."
	private static let syncLibraryLink = URL.musicApp
	private static let syncLibraryButton: LocalizedStringKey = "Open Music"
#else
	private static let syncLibraryHelp: LocalizedStringKey = "Favorites sync through iCloud. Turn on Sync Library in Settings > Music, or favorite songs in the Music app instead."
	private static let syncLibraryLink = URL(string: "App-prefs:MUSIC")!
	private static let syncLibraryButton: LocalizedStringKey = "Open Settings"
#endif

	private func list(_ suggestions: [FavoriteSuggestion]) -> some View {
		List {
			Section {
				ForEach(suggestions) { suggestion in
					SuggestionRow(suggestion: suggestion, isFavorited: favorited.contains(suggestion.id), isPending: pending.contains(suggestion.id)) {
						favorite(suggestion)
					}
				}
			} header: {
				Text("Your most played songs that aren't favorited yet. Tap a song to hear it, and favorite the ones you love to add them to your playlists.")
					.textCase(nil)
					.foregroundStyle(Color.secondaryText)
			} footer: {
				Text("Favorites can take a moment to sync. Songs that aren't from Apple Music can only be favorited in the Music app.")
					.foregroundStyle(Color.secondaryText)
			}
		}
	}

	private func favorite(_ suggestion: FavoriteSuggestion) {
		guard !favorited.contains(suggestion.id), pending.insert(suggestion.id).inserted else { return }
		Task {
			do {
				try await AppleMusicFavorites.favorite(storeID: suggestion.storeID)
				favorited.insert(suggestion.id)
				AccessibilityNotification.Announcement("Favorited \(suggestion.title)").post()
			} catch {
				log.error("Unable to favorite \(suggestion.storeID, privacy: .public): \(error)")
				failed = suggestion
			}
			pending.remove(suggestion.id)
		}
	}
}

private struct SuggestionRow: View {
	let suggestion: FavoriteSuggestion
	let isFavorited: Bool
	let isPending: Bool
	let favorite: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			Button {
				playSongs([suggestion.item], addToQueue: false, opensMusic: false)
			} label: {
				HStack(spacing: 12) {
					AlbumArt(artist: suggestion.artist, artwork: suggestion.artwork, displayWidth: 48)
					VStack(alignment: .leading, spacing: 2) {
						Text(suggestion.title)
							.lineLimit(1)
						Text("\(suggestion.artist) · \(suggestion.playCount) plays")
							.font(.subheadline)
							.foregroundStyle(Color.secondaryText)
							.lineLimit(1)
					}
					Spacer(minLength: 0)
				}
					.contentShape(.rect)
			}
				.buttonStyle(.plain)
				.accessibilityLabel("\(suggestion.title), \(suggestion.artist), \(suggestion.playCount) plays")
				.accessibilityHint("Plays the song")
			Button(isFavorited ? "Favorited" : "Favorite", systemImage: isFavorited ? "heart.fill" : "heart", action: favorite)
				.labelStyle(.iconOnly)
				.font(.title2)
				.foregroundStyle(isFavorited ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondaryText))
				.symbolEffect(.bounce, value: isFavorited)
				.buttonStyle(.borderless)
				.disabled(isFavorited || isPending)
				.opacity(isPending ? 0.4 : 1)
				.frame(minWidth: 44, minHeight: 44)
		}
	}
}
