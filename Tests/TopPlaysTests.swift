import Foundation
import Testing
@testable import Heart_Beats

struct TopPlaysTests {
	private func entry(_ name: String) -> MediaEntry {
		MediaEntry(id: name, songs: nil, songCount: 10, artwork: nil)
	}

	@Test func ranksMostPlayedFirstThenListOrder() {
		let entries = ["A", "B", "C", "D"].map(entry)
		let records = [
			"c": PlayRecord(name: "C", count: 3, lastPlayed: .distantPast),
			"b": PlayRecord(name: "B", count: 1, lastPlayed: .now),
		]
		#expect(TopPlaysWriter.ranked(entries, records: records, playCounts: [:]).map(\.id) == ["C", "B", "A", "D"])
	}

	@Test func breaksTiesByMostRecentPlay() {
		let entries = ["A", "B"].map(entry)
		let records = [
			"a": PlayRecord(name: "A", count: 2, lastPlayed: .distantPast),
			"b": PlayRecord(name: "B", count: 2, lastPlayed: .now),
		]
		#expect(TopPlaysWriter.ranked(entries, records: records, playCounts: [:]).map(\.id) == ["B", "A"])
	}

	@Test func matchesNamesIgnoringCase() {
		let records = ["sigur rós": PlayRecord(name: "Sigur Rós", count: 1, lastPlayed: .now)]
		#expect(TopPlaysWriter.ranked(["Toe", "Sigur Rós"].map(entry), records: records, playCounts: [:]).map(\.id) == ["Sigur Rós", "Toe"])
	}

	@Test func ranksMusicPlayCountsAboveAppPlays() {
		let entries = ["A", "B", "C"].map(entry)
		let records = ["a": PlayRecord(name: "A", count: 9, lastPlayed: .now)]
		let playCounts = ["b": 50, "c": 120, "a": 50]
		#expect(TopPlaysWriter.ranked(entries, records: records, playCounts: playCounts).map(\.id) == ["C", "A", "B"])
	}
}

struct PlayCountTests {
	private struct Song: LibrarySong {
		var artist: String?
		var albumArtist: String?
		var genre: String?
		var rating = 0
		var isFavoriteSong = false
		var playCount: Int
		var dateAdded = Date(timeIntervalSince1970: 0)
	}

	@Test func sumsEverySongsPlaysPerArtistAfterCombining() {
		let songs = [
			Song(artist: "Sufjan", playCount: 3),
			Song(artist: "Sufjan Stevens", playCount: 4),
			Song(artist: "Toe", playCount: 2),
			Song(artist: "Toe", playCount: 0),
		]
		let counts = LibraryGrouping.playCounts(songs, groupBy: "artist", combined: [["Sufjan Stevens", "Sufjan"]])
		#expect(counts == ["sufjan stevens": 7, "toe": 2])
	}

	@Test func countsASongOncePerGenre() {
		let songs = [Song(genre: "Rock, Indie, rock", playCount: 5)]
		#expect(LibraryGrouping.playCounts(songs, groupBy: "genre", combined: []) == ["rock": 5, "indie": 5])
	}
}
