import XCTest

/// Measures scroll hitches in every list on a device. Run with the "Heart Beats Scroll Tests" scheme, which builds Release.
///
/// XCTest rather than Swift Testing: Xcode doesn't allow Swift Testing in UI test bundles, and its scroll metric is XCTest-only. XCTest creates test cases off the main actor, so only the tests themselves are isolated to it.
nonisolated final class ScrollTests: XCTestCase {
	@MainActor
	func testScrollingArtists() {
		let app = launch()
		measureScrolling(in: app, tab: "Artists")
	}

	@MainActor
	func testScrollingArtistsGrid() {
		let app = launch()
		select(tab: "Artists", in: app)
		let toggle = layoutToggle(in: app)
		toggle.tap()
		measureScrolling(in: app, tab: nil)
		// Leaves the layout as it was
		toggle.tap()
	}

	@MainActor
	func testScrollingGenres() {
		let app = launch()
		measureScrolling(in: app, tab: "Genres")
	}

	@MainActor
	func testScrollingYears() {
		let app = launch()
		measureScrolling(in: app, tab: "Years")
	}

	@MainActor
	private func launch() -> XCUIApplication {
		continueAfterFailure = false
		let app = XCUIApplication()
		app.launch()
		return app
	}

	@MainActor
	private func layoutToggle(in app: XCUIApplication) -> XCUIElement {
		let toggle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Show as'")).firstMatch
		XCTAssert(toggle.waitForExistence(timeout: 5), "No list/grid toggle")
		return toggle
	}

	@MainActor
	private func select(tab: String, in app: XCUIApplication) {
		let button = app.buttons[tab].firstMatch
		XCTAssert(button.waitForExistence(timeout: 10), "No \(tab) tab")
		button.tap()
	}

	/// Each iteration flings to the bottom and back; only the fling down is measured.
	@MainActor
	private func measureScrolling(in app: XCUIApplication, tab: String?) {
		if let tab {
			select(tab: tab, in: app)
		}
		// Lists are collection views; the grids are plain scroll views
		let list = app.collectionViews.firstMatch.waitForExistence(timeout: 5) ? app.collectionViews.firstMatch : app.scrollViews.firstMatch
		XCTAssert(list.waitForExistence(timeout: 10), "No scrolling list on \(tab ?? "the grid")")

		let options = XCTMeasureOptions()
		options.invocationOptions = [.manuallyStop]
		measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
			list.swipeUp(velocity: .fast)
			stopMeasuring()
			list.swipeDown(velocity: .fast)
		}
	}
}
