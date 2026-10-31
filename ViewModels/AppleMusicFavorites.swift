import MediaPlayer
import MusicKit

/// Favorites songs in Apple Music, the same as the star in Music. Apps can't set star ratings, only favorites.
enum AppleMusicFavorites {
	/// Fewer 5-star and favorited songs than this, and the lists come out thin, so Getting Started offers to help.
	static let enoughSongs = 100
	/// With at least this many played songs to suggest, favoriting them here is the quickest way to grow the lists
	static let enoughSuggestions = 25

	enum Availability {
		case available
		/// Favorites go through iCloud, so Sync Library has to be on
		case needsSyncLibrary
		case unavailable
	}

	static func availability() async -> Availability {
		guard await MusicAuthorization.request() == .authorized, let subscription = try? await MusicSubscription.current else { return .unavailable }
		return subscription.hasCloudLibraryEnabled ? .available : .needsSyncLibrary
	}

	/// Adds a catalog song to the user's favorites. Music picks the change up through iCloud, which then updates the library.
	static func favorite(storeID: String) async throws {
		var components = URLComponents(string: "https://api.music.apple.com/v1/me/favorites")!
		components.queryItems = [URLQueryItem(name: "ids[songs]", value: storeID)]
		var request = URLRequest(url: components.url!)
		request.httpMethod = "POST"
		_ = try await MusicDataRequest(urlRequest: request).response()
	}

	/// The most played songs that aren't 5 stars or favorited yet, which are the likeliest to be loved.
	static func suggestions(limit: Int = 150) async -> [FavoriteSuggestion] {
		guard let songs = await MusicLibrary.songs() else { return [] }
		return await MediaPlayerQueue.run {
			let candidates = songs.details
				.filter { !$0.isTopRated && $0.playCount > 1 }
				.sorted { $0.playCount > $1.playCount }
			var suggestions: [FavoriteSuggestion] = []
			for song in candidates {
				// Only Apple Music catalog songs can be favorited from here
				let item = songs.items[song.index]
				guard let storeID = item.playbackStoreID.nonEmptyStoreID else { continue }
				suggestions.append(FavoriteSuggestion(item: item, storeID: storeID, playCount: song.playCount))
				if suggestions.count >= limit {
					break
				}
			}
			return suggestions
		}
	}
}

/// A song offered to favorite. MediaPlayer items aren't marked Sendable, but they're read-only snapshots of the library.
nonisolated struct FavoriteSuggestion: Identifiable, @unchecked Sendable {
	let item: MPMediaItem
	let storeID: String
	let playCount: Int
	let id: MPMediaEntityPersistentID
	let title: String
	let artist: String
	let artwork: ArtworkCache.Artwork?

	init(item: MPMediaItem, storeID: String, playCount: Int) {
		self.item = item
		self.storeID = storeID
		self.playCount = playCount
		id = item.persistentID
		title = item.title ?? "Untitled"
		artist = item.artist ?? item.albumArtist ?? ""
		artwork = ArtworkCache.Artwork(song: item)
	}
}

private extension String {
	/// Songs not from the catalog (like imported files) have an empty or zero store ID
	nonisolated var nonEmptyStoreID: String? {
		isEmpty || self == "0" ? nil : self
	}
}
