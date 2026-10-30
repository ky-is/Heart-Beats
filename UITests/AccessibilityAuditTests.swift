import XCTest

/// Runs Xcode's accessibility audit (contrast, clipped text, Dynamic Type, hit regions, labels, traits) on every screen of the sample library. Run in the simulator with the "Heart Beats Scroll Tests" scheme.
///
/// Every issue on a screen is listed before the test fails, so one run shows them all. Skipped, as the audit can't judge them:
/// - Contrast of anything on or under glass (the tab bar, the minimum button, nav bar buttons, rows scrolled beneath a bar): glass takes its color from whatever is behind it, and the audit samples one frame.
/// - Dynamic Type on the tab bar and nav bar buttons, which keep a fixed size like the system's in a fixed-height bar and show the Large Content Viewer on a long press instead.
/// - Dynamic Type on the Settings version footer, flagged as "partially unsupported" however it's laid out, though it grows like the rows around it (checked at the largest accessibility size).
/// Issues the audit can't tie to an element are printed but don't fail, since there's nothing to point a fix at.
nonisolated final class AccessibilityAuditTests: XCTestCase {
	@MainActor
	func testArtistsList() throws {
		let app = launch(tab: "artists", mode: "list")
		try audit(app, "Artists list")
	}

	@MainActor
	func testArtistsGrid() throws {
		let app = launch(tab: "artists", mode: "grid")
		try audit(app, "Artists grid")
	}

	@MainActor
	func testGenres() throws {
		let app = launch(tab: "genres", mode: "list")
		try audit(app, "Genres")
	}

	@MainActor
	func testYears() throws {
		let app = launch(tab: "years", mode: "grid")
		try audit(app, "Years")
	}

	@MainActor
	func testMinimumPopover() throws {
		let app = launch(tab: "artists", mode: "list")
		let button = app.buttons["Minimum songs"].firstMatch
		XCTAssert(button.waitForExistence(timeout: 10), "No minimum button")
		button.tap()
		XCTAssert(app.buttons["More songs"].waitForExistence(timeout: 5), "No popover")
		try audit(app, "Minimum popover")
	}

	@MainActor
	func testSettingsAndCombine() throws {
		let app = launch(tab: "artists", mode: "list")
		let settings = app.buttons["Settings"].firstMatch
		XCTAssert(settings.waitForExistence(timeout: 10), "No Settings button")
		settings.tap()
		let combine = app.buttons["Combine Artists"]
		XCTAssert(combine.waitForExistence(timeout: 5), "No Settings sheet")
		try audit(app, "Settings")

		combine.tap()
		let create = app.buttons["Create new"]
		XCTAssert(create.waitForExistence(timeout: 5), "No Combine screen")
		try audit(app, "Combine Artists")

		create.tap()
		let into = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Combine Into'")).firstMatch
		XCTAssert(into.waitForExistence(timeout: 5), "No Create screen")
		try audit(app, "Create combination")

		into.tap()
		XCTAssert(app.searchFields.firstMatch.waitForExistence(timeout: 5), "No chooser")
		try audit(app, "Combination chooser")
	}

	@MainActor
	private func launch(tab: String, mode: String) -> XCUIApplication {
		continueAfterFailure = true
		let app = XCUIApplication()
		app.launchArguments += ["-selectedTab", tab, "-listViewMode", mode]
		app.launch()
		// The first rows are drawn once the tab bar is up
		XCTAssert(app.buttons["Artists"].firstMatch.waitForExistence(timeout: 10), "App didn't launch")
		return app
	}

	/// Audits the screen showing, failing once with every issue found
	@MainActor
	private func audit(_ app: XCUIApplication, _ screen: String) throws {
		var issues: [String] = []
		// The glass bars: the tab bar (or the minimum button beside it) at the bottom, the nav bar at the top
		let barButtons = ["Artists", "Genres", "Years", "Minimum songs"].flatMap { app.buttons.matching(identifier: $0).allElementsBoundByIndex }
		let bottomBarTop = barButtons.map(\.frame.minY).filter(\.isFinite).filter { $0 > app.frame.midY }.min() ?? .infinity
		let topBars = app.navigationBars.allElementsBoundByIndex.map(\.frame)
		try app.performAccessibilityAudit { issue in
			guard let element = issue.element else {
				print("AUDIT (not failing, no element) [\(screen)] \(issue.compactDescription): \(issue.detailedDescription)")
				return true
			}
			let frame = element.frame
			let isBarButton = element.elementType == .button && (frame.minY >= bottomBarTop || topBars.contains { $0.contains(frame) })
			let onGlass = isBarButton || frame.maxY > bottomBarTop || topBars.contains { $0.intersects(frame) && !$0.contains(frame) }
			switch issue.auditType {
			case .contrast where onGlass, .dynamicType where isBarButton, .textClipped where isBarButton:
				print("AUDIT (skipped, glass bar) [\(screen)] \(issue.compactDescription) — '\(element.label)'")
			case .dynamicType where element.label.hasSuffix(" by Kyle Coburn"):
				print("AUDIT (skipped, version footer) [\(screen)] \(issue.compactDescription)")
			default:
				issues.append("[\(screen)] \(issue.compactDescription) — \(element.elementType.rawValue) '\(element.label)': \(issue.detailedDescription)")
			}
			// Handled, so the audit keeps going and the rest are listed too
			return true
		}
		for issue in issues {
			print("AUDIT \(issue)")
		}
		XCTAssert(issues.isEmpty, "\(issues.count) accessibility issues on \(screen):\n" + issues.joined(separator: "\n"))
	}
}
