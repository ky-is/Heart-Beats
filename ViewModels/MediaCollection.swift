import MediaPlayer
import Observation
import SwiftUI

struct MediaEntry: Identifiable, Hashable {
	let id: String
	let songs: [MPMediaItem]?
	let songCount: Int
	let artwork: MPMediaItemArtwork?
}

@Observable
final class MediaCollection {
	static let artists = MediaCollection(groupBy: "artist")
	static let genres = MediaCollection(groupBy: "genre")

	let groupBy: String

	var unavailable: MPMediaLibraryAuthorizationStatus?
#if targetEnvironment(simulator)
	var entries: [MediaEntry] = MediaCollection.screenshotData
#else
	var entries: [MediaEntry] = []
#endif
	var maximumSongsLimit = 99

	init(groupBy: String) {
		self.groupBy = groupBy

		if self.entries.isEmpty, let cache = groupBy == "genre" ? UserDefaults.standard.cachedGenres : UserDefaults.standard.cachedArtists {
			self.entries = cache
				.map { MediaEntry(id: $0[0] as! String, songs: nil, songCount: $0[1] as! Int, artwork: nil) }
		}
	}

	static var screenshotData: [MediaEntry] {
		return [
			MediaEntry(id: "The Album Leaf", songs: nil, songCount: 20, artwork: nil),
			MediaEntry(id: "Beach House", songs: nil, songCount: 50, artwork: nil),
			MediaEntry(id: "Belle & Sebastian", songs: nil, songCount: 51, artwork: nil),
			MediaEntry(id: "Bob Marley & The Wailers", songs: nil, songCount: 33, artwork: nil),
			MediaEntry(id: "CHVRCHΞS", songs: nil, songCount: 23, artwork: nil),
			MediaEntry(id: "The Decemberists", songs: nil, songCount: 52, artwork: nil),
			MediaEntry(id: "Frédéric Chopin", songs: nil, songCount: 22, artwork: nil),
			MediaEntry(id: "indigo la End", songs: nil, songCount: 37, artwork: nil),
			MediaEntry(id: "Lost Frequencies", songs: nil, songCount: 23, artwork: nil),
			MediaEntry(id: "The National", songs: nil, songCount: 61, artwork: nil),
			MediaEntry(id: "Polo & Pan", songs: nil, songCount: 16, artwork: nil),
			MediaEntry(id: "Sigur Rós", songs: nil, songCount: 30, artwork: nil),
			MediaEntry(id: "Stromae", songs: nil, songCount: 15, artwork: nil),
			MediaEntry(id: "Sufjan Stevens", songs: nil, songCount: 16, artwork: nil),
			MediaEntry(id: "Toe", songs: nil, songCount: 34, artwork: nil),
			MediaEntry(id: "Yelle", songs: nil, songCount: 26, artwork: nil),
		]
	}

	class var current: MediaCollection {
		UserDefaults.standard.showGenres ? genres : artists
	}

	class func updateCurrent(withAnimation: Bool) {
		Task {
			if UserDefaults.standard.showGenres {
				await genres.update(withAnimation: withAnimation)
			} else {
				await artists.update(withAnimation: withAnimation)
			}
		}
	}

	class func updateBackground() {
		Task(priority: .background) {
			if UserDefaults.standard.showGenres {
				await artists.update(withAnimation: false)
			} else {
				await genres.update(withAnimation: false)
			}
		}
	}

	class func setUnavailable(status: MPMediaLibraryAuthorizationStatus) {
		artists.unavailable = status
	}

	private func update(withAnimation animated: Bool) async {
		let showGenres = groupBy == "genre"
		let query = showGenres ? MPMediaQuery.genres() : MPMediaQuery.artists()
		guard let rawCollections = query.collections else {
			return print("Unable to load music")
		}
		let favorited = UserDefaults.standard.currentFavorites
		let combined = UserDefaults.standard.currentCombined
		var collectionsAcc = [String: (String, MPMediaItem, [MPMediaItem])]()
		var mostSongsAcc = 0
		for collection in rawCollections {
			let representative: MPMediaItem?
			if collection.representativeItem?.artwork != nil {
				representative = collection.representativeItem
			} else {
				representative = collection.items.first { $0.artwork != nil }
			}
			guard let representative else {
				continue
			}
			var checkNames = [String]()
			if showGenres {
				if let genres = representative.genre?.split(separator: ",") {
					checkNames = genres.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				}
			} else {
				let albumArtist = representative.albumArtist
				if let albumArtist = albumArtist {
					checkNames.append(albumArtist)
				}
				if let artist = representative.artist, artist != albumArtist {
					checkNames.append(artist)
				}
			}
			guard !checkNames.isEmpty else {
				continue
			}
			for var name in checkNames {
				var checkName = name.lowercased()
#if targetEnvironment(simulator)
				if !showGenres && !self.entries.contains(where: { $0.id.lowercased() == checkName }) {
					continue
				}
#endif
				if !showGenres && checkName == "various artists" {
					continue
				}
				for combining in combined {
					if let index = combining.firstIndex(of: name), index > 0 {
						name = combining[0]
						checkName = name.lowercased()
						break
					}
				}
				let songs = collection.items.filter { $0.rating >= 5 }
				if collectionsAcc[checkName] != nil {
					collectionsAcc[checkName]!.2.append(contentsOf: songs)
				} else {
					collectionsAcc[checkName] = (name, representative, songs)
				}
				let newTotal = collectionsAcc[checkName]!.2.count
				if newTotal > mostSongsAcc {
					mostSongsAcc = newTotal
				}
			}
		}
		let collections = collectionsAcc.values
		let mostSongsLimit = min(99, mostSongsAcc)
		let exceedsMostNumberOfSongs = UserDefaults.standard.minimum > mostSongsLimit
		let allowedMinimumNumberOfSongs = exceedsMostNumberOfSongs ? mostSongsLimit : UserDefaults.standard.minimum
		let entries = collections
			.filter { $0.2.count >= allowedMinimumNumberOfSongs || ($0.2.count > 0 && favorited.contains($0.0)) }
			.sorted { $0.0.forSorting.localizedStandardCompare($1.0.forSorting) == .orderedAscending }
			.map { MediaEntry(id: $0.0, songs: $0.2, songCount: $0.2.count, artwork: $0.1.artwork) }
		let updatesMinimum = UserDefaults.standard.showGenres == showGenres && exceedsMostNumberOfSongs && allowedMinimumNumberOfSongs > 0
		Task { @MainActor in
			if animated {
				withAnimation {
					apply(allowedMinimumNumberOfSongs: updatesMinimum ? allowedMinimumNumberOfSongs : nil, mostSongsLimit: mostSongsLimit, entries: entries)
				}
			} else {
				apply(allowedMinimumNumberOfSongs: updatesMinimum ? allowedMinimumNumberOfSongs : nil, mostSongsLimit: mostSongsLimit, entries: entries)
			}
		}
		let cache = entries.map { [$0.id, $0.songCount] }
		if showGenres {
			UserDefaults.standard.cachedGenres = cache
		} else {
			UserDefaults.standard.cachedArtists = cache
		}
	}

	private func apply(allowedMinimumNumberOfSongs: Int?, mostSongsLimit: Int, entries: [MediaEntry]) {
		if let allowedMinimumNumberOfSongs {
			UserDefaults.standard.minimum = allowedMinimumNumberOfSongs
		}
		self.maximumSongsLimit = mostSongsLimit
		self.entries = entries
	}
}
