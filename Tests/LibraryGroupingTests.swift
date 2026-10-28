import Foundation
import Testing
@testable import Heart_Beats

struct FakeSong: LibrarySong, Equatable {
	var title = ""
	var artist: String?
	var albumArtist: String?
	var genre: String?
	var rating = 5
	var playCount = 0
	var dateAdded = Date(timeIntervalSince1970: 0)
}

private func counts(_ groups: [LibraryGrouping.Group<FakeSong>]) -> [String: Int] {
	Dictionary(uniqueKeysWithValues: groups.map { ($0.name, $0.songs.count) })
}

struct ArtistGroupingTests {
	@Test func countsEachSongOnceUnderItsAlbumArtist() {
		let songs = [
			FakeSong(title: "Feature", artist: "Rihanna", albumArtist: "Drake"),
			FakeSong(title: "Own song", artist: "Rihanna", albumArtist: "Rihanna"),
			FakeSong(title: "Single", artist: "Drake", albumArtist: nil),
		]
		let groups = LibraryGrouping.group(songs, groupBy: "artist", combined: [])
		#expect(counts(groups) == ["Drake": 2, "Rihanna": 1])
		#expect(groups.map(\.songs.count).reduce(0, +) == songs.count)
	}

	@Test func compilationsUseTheTrackArtist() {
		let songs = [
			FakeSong(artist: "Toe", albumArtist: "Various Artists"),
			FakeSong(artist: "Various Artists", albumArtist: "various artists"),
		]
		#expect(counts(LibraryGrouping.group(songs, groupBy: "artist", combined: [])) == ["Toe": 1])
	}

	@Test func mergesNamesRegardlessOfCase() {
		let songs = [
			FakeSong(artist: "The National"),
			FakeSong(artist: "the national "),
		]
		let groups = LibraryGrouping.group(songs, groupBy: "artist", combined: [])
		#expect(groups.count == 1)
		#expect(groups.first?.songs.count == 2)
	}

	@Test func ignoresSongsBelowFiveStars() {
		let songs = [
			FakeSong(artist: "Yelle", rating: 4),
			FakeSong(artist: "Yelle", rating: 0),
		]
		#expect(LibraryGrouping.group(songs, groupBy: "artist", combined: []).isEmpty)
	}

	@Test func combinesIntoTheTargetName() {
		let songs = [
			FakeSong(artist: "Sufjan Stevens"),
			FakeSong(artist: "SUFJAN"),
			FakeSong(artist: "Stromae"),
		]
		let groups = LibraryGrouping.group(songs, groupBy: "artist", combined: [["Sufjan Stevens", "Sufjan"]])
		#expect(counts(groups) == ["Sufjan Stevens": 2, "Stromae": 1])
	}

	@Test func skipsSongsWithoutAnArtist() {
		#expect(LibraryGrouping.group([FakeSong(artist: " ")], groupBy: "artist", combined: []).isEmpty)
	}
}

struct GenreGroupingTests {
	@Test func listsASongUnderEachOfItsGenres() {
		let songs = [FakeSong(genre: "Rock, Pop"), FakeSong(genre: "Rock")]
		#expect(counts(LibraryGrouping.group(songs, groupBy: "genre", combined: [])) == ["Rock": 2, "Pop": 1])
	}

	@Test func countsASongOnceWhenItsGenresMatch() {
		let songs = [FakeSong(genre: "Rock, rock,  ")]
		#expect(counts(LibraryGrouping.group(songs, groupBy: "genre", combined: [])) == ["Rock": 1])
	}

	@Test func countsASongOnceWhenItsGenresCombine() {
		let songs = [FakeSong(genre: "Rock, Alt Rock")]
		let groups = LibraryGrouping.group(songs, groupBy: "genre", combined: [["Rock", "Alt Rock"]])
		#expect(counts(groups) == ["Rock": 1])
	}
}

struct SelectionTests {
	private func groups(_ sizes: [String: Int]) -> [LibraryGrouping.Group<FakeSong>] {
		sizes.map { LibraryGrouping.Group(name: $0.key, songs: Array(repeating: FakeSong(artist: $0.key), count: $0.value)) }
	}

	@Test func keepsGroupsAtTheMinimumPlusFavorites() {
		let (selected, limit) = LibraryGrouping.select(groups(["Toe": 20, "Yelle": 3, "Stromae": 14]), minimum: 15, favorites: ["yelle"])
		#expect(selected.map(\.name) == ["Toe", "Yelle"])
		#expect(limit == 20)
	}

	@Test func capsTheMinimumToTheLargestGroup() {
		let (selected, limit) = LibraryGrouping.select(groups(["Toe": 8, "Yelle": 3]), minimum: 50, favorites: [])
		#expect(selected.map(\.name) == ["Toe"])
		#expect(limit == 8)
	}

	@Test func capsTheLimitAt99() {
		let (_, limit) = LibraryGrouping.select(groups(["Toe": 150]), minimum: 15, favorites: [])
		#expect(limit == LibraryGrouping.minimumSongsCap)
	}

	@Test func sortsIgnoringALeadingThe() {
		let (selected, _) = LibraryGrouping.select(groups(["The National": 1, "Beach House": 1, "Toe": 1, "the Album Leaf": 1]), minimum: 1, favorites: [])
		#expect(selected.map(\.name) == ["the Album Leaf", "Beach House", "The National", "Toe"])
	}

	@Test func handlesAnEmptyLibrary() {
		let (selected, limit) = LibraryGrouping.select([LibraryGrouping.Group<FakeSong>](), minimum: 15, favorites: ["Toe"])
		#expect(selected.isEmpty)
		#expect(limit == 0)
	}
}

struct YearsInReviewTests {
	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "UTC")!
		return calendar
	}()

	private func song(_ title: String, year: Int, plays: Int, rating: Int = 0) -> FakeSong {
		FakeSong(title: title, rating: rating, playCount: plays, dateAdded: calendar.date(from: DateComponents(year: year, month: 6, day: 1))!)
	}

	@Test func keepsEachYearsMostPlayedSongs() {
		var songs = (1...5).map { song("hit \($0)", year: 2024, plays: 60 + $0) }
		songs += [
			song("rated", year: 2024, plays: 20, rating: 5),
			song("unrated", year: 2024, plays: 20),
			song("rarely played", year: 2024, plays: 5, rating: 5),
			song("played once", year: 2024, plays: 1, rating: 5),
		]
		let years = LibraryGrouping.yearsInReview(songs, calendar: calendar)
		#expect(years.map(\.year) == [2024])
		#expect(years[0].songs.map(\.title) == ["hit 5", "hit 4", "hit 3", "hit 2", "hit 1", "rated"])
	}

	@Test func skipsYearsWithFewerThanFiveSongs() {
		let songs = (1...4).map { song("hit \($0)", year: 2023, plays: 80) }
		#expect(LibraryGrouping.yearsInReview(songs, calendar: calendar).isEmpty)
	}

	@Test func scalesThresholdsToTheYearsTopSong() {
		// Top song has 1000 plays, so songs need over 500 plays (or 100+ and 5 stars)
		var songs = [song("top", year: 2022, plays: 1000)]
		songs += (1...4).map { song("big \($0)", year: 2022, plays: 600) }
		songs += [song("medium", year: 2022, plays: 300), song("medium rated", year: 2022, plays: 300, rating: 5), song("low rated", year: 2022, plays: 50, rating: 5)]
		let titles = LibraryGrouping.yearsInReview(songs, calendar: calendar).first?.songs.map(\.title) ?? []
		#expect(Set(titles) == ["top", "big 1", "big 2", "big 3", "big 4", "medium rated"])
	}

	@Test func listsNewestYearFirst() {
		let songs = [2019, 2025, 2021].flatMap { year in (1...5).map { song("\(year)-\($0)", year: year, plays: 200) } }
		#expect(LibraryGrouping.yearsInReview(songs, calendar: calendar).map(\.year) == [2025, 2021, 2019])
	}
}

struct StringTests {
	@Test func normalizesCaseAndWhitespace() {
		#expect(" The National\n".normalized() == "the national")
		#expect(["Toe", "Yelle"].containsNormalized("yelle "))
		#expect(!["Toe"].containsNormalized("Toes"))
	}

	@Test func sortKeyDropsALeadingThe() {
		#expect("The National".forSorting == "national")
		#expect("Theory".forSorting == "theory")
	}
}
