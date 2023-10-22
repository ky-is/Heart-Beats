import MediaPlayer
import Observation
import SwiftUI

struct MediaEntry: Identifiable, Hashable {
	let id: String
	let songs: MPMediaItemCollection?
	let songCount: Int
	let artwork: MPMediaItemArtwork?
}

@Observable
final class MediaCollection {
	static let artists = MediaCollection(groupBy: "artist")
	static let genres = MediaCollection(groupBy: "genre")

	let groupBy: String

	var unavailable: MPMediaLibraryAuthorizationStatus?
	var entries: [MediaEntry] = []
	var maximumSongsLimit = 99

	init(groupBy: String) {
		self.groupBy = groupBy
#if targetEnvironment(simulator)
		self.entries = Self.screenshotData
#elseif DEBUG
		if SCREENSHOT_MODE {
			self.entries = Self.screenshotData
		}
#endif
		if self.entries.isEmpty, let cache = groupBy == "genre" ? UserDefaults.standard.cachedGenres : UserDefaults.standard.cachedArtists {
			self.entries = cache
				.map { MediaEntry(id: $0[0] as! String, songs: nil, songCount: $0[1] as! Int, artwork: nil) }
		}
	}

	static var screenshotData: [MediaEntry] {
		return [
			MediaEntry(id: "Beach House", songs: nil, songCount: 50, artwork: nil),
			MediaEntry(id: "CHVRCHΞS", songs: nil, songCount: 23, artwork: nil),
			MediaEntry(id: "indigo la End", songs: nil, songCount: 37, artwork: nil),
			MediaEntry(id: "Lost Frequencies", songs: nil, songCount: 23, artwork: nil),
			MediaEntry(id: "The National", songs: nil, songCount: 61, artwork: nil),
			MediaEntry(id: "Sigur Rós", songs: nil, songCount: 30, artwork: nil),
			MediaEntry(id: "Stromae", songs: nil, songCount: 15, artwork: nil),
			MediaEntry(id: "The Album Leaf", songs: nil, songCount: 20, artwork: nil),
			MediaEntry(id: "Belle & Sebastian", songs: nil, songCount: 51, artwork: nil),
			MediaEntry(id: "Bob Marley & The Wailers", songs: nil, songCount: 33, artwork: nil),
			MediaEntry(id: "The Decemberists", songs: nil, songCount: 52, artwork: nil),
		]
	}

	class var current: MediaCollection {
		SyncStorage.shared.showGenres ? genres : artists
	}

	class func updateCurrent() {
		Task {
			if SyncStorage.shared.showGenres {
				await genres.update()
			} else {
				await artists.update()
			}
		}
	}

	class func updateBackground() {
		Task(priority: .background) {
			if SyncStorage.shared.showGenres {
				await artists.update()
			} else {
				await genres.update()
			}
		}
	}

	class func setUnavailable(status: MPMediaLibraryAuthorizationStatus) {
		artists.unavailable = status
	}

	private func update() async {
		let showGenres = groupBy == "genre"
		let query = showGenres ? MPMediaQuery.genres() : MPMediaQuery.artists()
		guard let rawCollections = query.collections else {
			return print("Unable to load music")
		}
		let favorited = SyncStorage.shared.currentFavorites
		let combined = SyncStorage.shared.currentCombined
		var collectionsAcc = [String: (String, MPMediaItem, [MPMediaItem])]()
		var mostSongsAcc = 0
		for collection in rawCollections {
			guard let representative = collection.representativeItem else {
				print("No \(groupBy)", collection)
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
#if DEBUG
				if SCREENSHOT_MODE && !self.entries.contains(where: { $0.id.lowercased() == checkName }) {
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
		let exceedsMostNumberOfSongs = SyncStorage.shared.minimum > mostSongsLimit
		let allowedMinimumNumberOfSongs = exceedsMostNumberOfSongs ? mostSongsLimit : SyncStorage.shared.minimum
		let entries = collections
			.filter { $0.2.count >= allowedMinimumNumberOfSongs || favorited.contains($0.0) }
			.sorted { $0.0.forSorting.localizedStandardCompare($1.0.forSorting) == .orderedAscending }
			.map { MediaEntry(id: $0.0, songs: MPMediaItemCollection(items: $0.2), songCount: $0.2.count, artwork: $0.1.artwork) }
		Task { @MainActor in
			withAnimation {
				if SyncStorage.shared.showGenres == showGenres && exceedsMostNumberOfSongs && allowedMinimumNumberOfSongs > 0 {
					SyncStorage.shared.minimum = allowedMinimumNumberOfSongs
				}
				self.maximumSongsLimit = mostSongsLimit
				self.entries = entries
				Task {
					let cache = entries.map { [$0.id, $0.songCount] }
					if showGenres {
						UserDefaults.standard.cachedGenres = cache
					} else {
						UserDefaults.standard.cachedArtists = cache
					}
				}
			}
		}

	}
}
