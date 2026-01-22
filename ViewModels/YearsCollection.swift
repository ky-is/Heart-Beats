import MediaPlayer
import Observation
import SwiftUI

@Observable
final class YearsCollection: MediaCollection {
#if targetEnvironment(simulator)
	var entries: [MediaEntry] = Self.screenshotData
#else
	var entries: [MediaEntry] = []
#endif

	init() {
		if let cache = UserDefaults.standard.cachedYears {
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

	internal func update(withAnimation animated: Bool) async {
		let query = MPMediaQuery.songs()
		guard let songs = query.items else { return print("Unable to load music") }

		var years: [Int: [MPMediaItem]] = [:]
		for song in songs {
			if song.playCount > 1 {
				let year = Calendar.current.component(.year, from: song.dateAdded)
				if years[year] == nil {
					years[year] = [song]
				} else {
					years[year]?.append(song)
				}
			}
		}

		// Collect filtered songs per year outside main actor
		var filteredYearSongs: [Int: [MPMediaItem]] = [:]
		for (year, entries) in years {
			let maxPlayCountCount = max(100, entries.reduce(0, { max($0, $1.playCount) }))
			let halfPlayCountCount = Int(Double(maxPlayCountCount) * 0.5)
			let minPlayCountCount = Int(Double(maxPlayCountCount) * 0.1)
			let songs = entries
				.filter { $0.playCount >= minPlayCountCount && ($0.playCount > halfPlayCountCount || $0.rating >= 5) }
				.sorted { $0.playCount > $1.playCount }
			if songs.count >= 5 {
				filteredYearSongs[year] = songs
			}
		}

		Task { @MainActor in
			var outputEntries: [MediaEntry] = []
			for (year, songs) in filteredYearSongs {
				outputEntries.append(MediaEntry(id: year.description, songs: songs, songCount: songs.count, artwork: songs[0].artwork))
			}
			outputEntries.sort { $0.id.compare($1.id) == .orderedDescending }
			if animated {
				withAnimation {
					self.entries = outputEntries
				}
			} else {
				self.entries = outputEntries
			}
			UserDefaults.standard.cachedYears = outputEntries.map { [$0.id, $0.songCount] }
		}
	}
}
