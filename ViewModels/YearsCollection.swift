import MediaPlayer
import Observation
import os
import SwiftUI

@Observable
final class YearsCollection: MediaCollection {
	static let shared = YearsCollection()

#if targetEnvironment(simulator)
	var entries: [MediaEntry] = YearsCollection.screenshotData
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

	private var pendingUpdate: Task<Void, Never>?
	private var generation = 0
	private var scannedLibraryDate: Date?

	func scheduleUpdate(withAnimation animated: Bool, after delay: Duration = .zero) {
		pendingUpdate?.cancel()
		pendingUpdate = Task {
			if delay > .zero {
				try? await Task.sleep(for: delay)
			}
			guard !Task.isCancelled else { return }
			await update(withAnimation: animated)
		}
	}

	/// Rescans only if the library changed since the last scan. With `onlyIfScanned`, skips a Years tab that was never opened.
	func updateIfLibraryChanged(onlyIfScanned: Bool = false, after delay: Duration = .zero) {
		// The simulator has no music library; a scan would replace the screenshot data
#if !targetEnvironment(simulator)
		guard !(onlyIfScanned && scannedLibraryDate == nil), MPMediaLibrary.default().lastModifiedDate != scannedLibraryDate else { return }
		scheduleUpdate(withAnimation: false, after: delay)
#endif
	}

	/// Scans every song off the main thread, then applies the result on it.
	@concurrent
	nonisolated func update(withAnimation animated: Bool) async {
		let currentGeneration = await MainActor.run {
			self.generation += 1
			self.scannedLibraryDate = MPMediaLibrary.default().lastModifiedDate
			return self.generation
		}
		guard let songs = MPMediaQuery.songs().items else {
			log.error("Unable to load music")
			return
		}
		let outputEntries = LibraryGrouping.yearsInReview(songs, calendar: .current)
			.map { MediaEntry(id: $0.year.description, songs: $0.songs, songCount: $0.songs.count, artwork: $0.songs[0].artwork) }

		await MainActor.run {
			// A newer scan started while this one ran, so its result wins
			guard currentGeneration == self.generation else { return }
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
