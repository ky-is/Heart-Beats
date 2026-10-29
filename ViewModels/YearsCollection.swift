import MediaPlayer
import Observation
import os
import SwiftUI

@Observable
final class YearsCollection {
	static let shared = YearsCollection()

	var entries: [MediaEntry]

	init() {
#if targetEnvironment(simulator)
		entries = ListCache.years.load() ?? MediaEntry.screenshotData
#else
		entries = ListCache.years.load() ?? []
#endif
	}

	@ObservationIgnored private var latestScan = LatestScan()
	/// The library version the shown entries were built from
	@ObservationIgnored private var scannedModifiedDate: Date?
	/// The library version the latest scheduled scan will read, so a "library changed?" check doesn't restart a scan that's already on its way
	@ObservationIgnored private var requestedModifiedDate: Date?

	func scheduleUpdate(withAnimation animated: Bool, after delay: Duration = .zero) {
		requestedModifiedDate = MusicLibrary.modifiedDate
		latestScan.start(after: delay) { [self] in
			await update(withAnimation: animated)
		}
	}

	/// Rescans only if the library changed since the last scan. With `onlyIfScanned`, skips a Years tab that was never opened.
	func updateIfLibraryChanged(onlyIfScanned: Bool = false, after delay: Duration = .zero) {
		// The simulator has no music library; a scan would replace the screenshot data
#if !targetEnvironment(simulator)
		let modifiedDate = MusicLibrary.modifiedDate
		guard !(onlyIfScanned && scannedModifiedDate == nil), modifiedDate != scannedModifiedDate, modifiedDate != requestedModifiedDate else { return }
		scheduleUpdate(withAnimation: false, after: delay)
#endif
	}

	private func update(withAnimation animated: Bool) async {
		guard let songs = await MusicLibrary.songs() else {
			// Lets the next check try again
			requestedModifiedDate = nil
			return
		}
		let years = await Self.years(songs, calendar: .current)
		let entries = await MediaPlayerQueue.run {
			signposter.withIntervalSignpost("Build years entries", id: signposter.makeSignpostID()) {
				years.value.map { MediaEntry(id: $0.year.description, songs: $0.songs) }
			}
		}
		// A newer scan replaced this one while it ran, so its result wins
		guard !Task.isCancelled else { return }

		scannedModifiedDate = songs.modifiedDate
		withAnimation(animated ? .default : nil) {
			self.entries = entries
		}
		ListCache.years.save(entries)
	}

	/// Picks each year's most played songs. Only reads song details, so it runs on any background thread.
	@concurrent
	private nonisolated static func years(_ songs: LibrarySongs, calendar: Calendar) async -> MediaPlayerValue<[(year: Int, songs: [MPMediaItem])]> {
		signposter.withIntervalSignpost("Scan years", id: signposter.makeSignpostID()) {
			MediaPlayerValue(value: LibraryGrouping.yearsInReview(songs.details, calendar: calendar).map { ($0.year, songs.items(for: $0.songs)) })
		}
	}
}
