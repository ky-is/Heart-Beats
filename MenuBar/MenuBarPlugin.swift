import AppKit
import os

/// The Mac menu bar item, a glass popover with a cover beside each entry. Mac Catalyst can't make one, so this AppKit bundle is loaded by the app at launch, and the two only share notifications with property list payloads (see MenuBar in the app).
///
/// The app's Dock icon goes away when its last window is closed, leaving this item to open the window again.
@objc(HBMenuBarPlugin)
final class MenuBarPlugin: NSObject {
	private enum Name {
		/// From the app: the lists to show
		static let update = Notification.Name("is.ky.Heart-Beats.menuBar.update")
		/// From the app: covers, by the album they belong to
		static let covers = Notification.Name("is.ky.Heart-Beats.menuBar.covers")
		/// To the app: an entry was picked
		static let play = Notification.Name("is.ky.Heart-Beats.menuBar.play")
		/// To the app: open its window
		static let open = Notification.Name("is.ky.Heart-Beats.menuBar.open")
	}

	private let log = Logger(subsystem: "is.ky.Heart-Beats", category: "menu-bar")
	private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
	private let popover = NSPopover()
	private let content = MenuBarViewController()

	override init() {
		super.init()
		if let button = statusItem.button {
			button.image = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: "Heart Beats")
			button.target = self
			button.action = #selector(statusItemClicked)
			button.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}
		content.play = { [weak self] name in self?.play(name) }
		content.open = { [weak self] in self?.openApp() }
		content.quit = { NSApp.terminate(nil) }
		popover.contentViewController = content
		// Closes on a click anywhere else
		popover.behavior = .transient
		observeApp()
		observeWindows()
		log.notice("Menu bar item ready")
	}

	// MARK: Popover

	@objc private func statusItemClicked() {
		if NSApp.currentEvent?.type == .rightMouseUp {
			showContextMenu()
		} else if popover.isShown {
			popover.performClose(nil)
		} else if let button = statusItem.button {
			popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
		}
	}

	/// Right-click gives the same two actions as the popover's buttons, for anyone who expects a menu.
	private func showContextMenu() {
		let menu = NSMenu()
		let open = NSMenuItem(title: "Open Heart Beats", action: #selector(openApp), keyEquivalent: "")
		open.target = self
		menu.addItem(open)
		menu.addItem(NSMenuItem(title: "Quit Heart Beats", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
		// A status item only shows its menu while it has one
		statusItem.menu = menu
		statusItem.button?.performClick(nil)
		statusItem.menu = nil
	}

	private func play(_ name: String) {
		popover.performClose(nil)
		NotificationCenter.default.post(name: Name.play, object: nil, userInfo: ["tab": content.tab, "name": name])
	}

	@objc private func openApp() {
		popover.performClose(nil)
		showInDock()
		// An open window may be behind other apps or minimized, which showInDock leaves alone
		NSApp.activate()
		let windows = appWindows()
		windows.filter(\.isMiniaturized).forEach { $0.deminiaturize(nil) }
		windows.first?.makeKeyAndOrderFront(nil)
		// With no window, the app opens one
		NotificationCenter.default.post(name: Name.open, object: nil)
	}

	// MARK: App

	private func observeApp() {
		NotificationCenter.default.addObserver(forName: Name.update, object: nil, queue: .main) { [weak self] note in
			// Property list values, only ever read on the main thread
			nonisolated(unsafe) let payload = note.userInfo?["lists"] as? [[String: Any]] ?? []
			MainActor.assumeIsolated {
				self?.content.apply(payload)
			}
		}
		NotificationCenter.default.addObserver(forName: Name.covers, object: nil, queue: .main) { [weak self] note in
			nonisolated(unsafe) let covers = note.userInfo?["covers"] as? [String: Data] ?? [:]
			MainActor.assumeIsolated {
				self?.content.addCovers(covers)
			}
		}
	}

	// MARK: Dock icon

	/// The Dock icon (and the app's own menu bar) stays only while a window is open.
	private func observeWindows() {
		let center = NotificationCenter.default
		center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
			let closing = (note.object as? NSWindow).map(ObjectIdentifier.init)
			MainActor.assumeIsolated {
				self?.hideFromDockIfWindowless(closing: closing)
			}
		}
		// A window can also open without the app being active (a new scene), so the app coming forward counts too
		for name in [NSWindow.didBecomeMainNotification, NSWindow.didBecomeKeyNotification, NSApplication.didBecomeActiveNotification] {
			center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
				MainActor.assumeIsolated {
					self?.showInDockIfWindowed()
				}
			}
		}
	}

	/// The popover is a window too, but it can't become main.
	private func appWindows(excluding closing: ObjectIdentifier? = nil) -> [NSWindow] {
		NSApp.windows.filter { ObjectIdentifier($0) != closing && $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized) }
	}

	private func hideFromDockIfWindowless(closing: ObjectIdentifier?) {
		guard appWindows(excluding: closing).isEmpty else { return }
		log.notice("Last window closed, leaving the Dock")
		NSApp.setActivationPolicy(.accessory)
	}

	private func showInDockIfWindowed() {
		if !appWindows().isEmpty {
			showInDock()
		}
	}

	private func showInDock() {
		guard NSApp.activationPolicy() != .regular else { return }
		NSApp.setActivationPolicy(.regular)
		// The app comes back without its menu bar until it's activated again
		NSApp.activate()
	}
}

// MARK: - Popover content

/// The popover: the tab control with Open and Quit beside it, over the selected tab's list. Plain AppKit, since SwiftUI can't be used here: the app has its Catalyst SwiftUI loaded already, which has none of the macOS-only parts.
///
/// Light on a big library: the view isn't built until the popover first opens, the list is a table that only makes the rows on screen, covers stay as the small JPEGs they arrive as until a row shows one, and a list that hasn't changed isn't reloaded.
private final class MenuBarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	private struct Item: Equatable {
		let name: String
		let songCount: Int
		let isFavorite: Bool
		/// The album its cover is kept under
		let cover: String?
	}

	private enum Row {
		case section(String)
		case entry(Item)
		case message(String)
	}

	private static let tabs = [(id: "artists", title: "Artists", empty: "No Artists Yet", rest: "All Artists"), (id: "genres", title: "Genres", empty: "No Genres Yet", rest: "All Genres"), (id: "years", title: "Years", empty: "No Years Yet", rest: "Years")]
	private static let selectedTabKey = "menuBarTab"
	private static let width: CGFloat = 320
	private static let rowHeight: CGFloat = 40
	private static let sectionTitleHeight: CGFloat = 26
	private static let maximumListHeight: CGFloat = 480

	var play: (String) -> Void = { _ in }
	var open: () -> Void = {}
	var quit: () -> Void = {}

	private(set) var tab = UserDefaults.standard.string(forKey: MenuBarViewController.selectedTabKey) ?? "artists" {
		didSet {
			UserDefaults.standard.set(tab, forKey: Self.selectedTabKey)
		}
	}
	private var lists: [String: [Item]] = [:]
	/// The covers as they arrived, a few KB each
	private var coverData: [String: Data] = [:]
	/// Decoded only for the rows shown, and dropped under memory pressure
	private let coverImages = NSCache<NSString, NSImage>()
	private var rows: [Row] = []

	private let tabControl = NSSegmentedControl(labels: MenuBarViewController.tabs.map(\.title), trackingMode: .selectOne, target: nil, action: nil)
	private let table = NSTableView()
	private let scrollView = NSScrollView()
	private var listHeight: NSLayoutConstraint?

	override func loadView() {
		tabControl.target = self
		tabControl.action = #selector(tabChanged)
		tabControl.segmentDistribution = .fillEqually
		tabControl.selectedSegment = Self.tabs.firstIndex { $0.id == tab } ?? 0
		tabControl.setAccessibilityLabel("List")
		let open = iconButton(symbol: "arrow.up.forward.app", title: "Open Heart Beats", action: #selector(openClicked))
		let quit = iconButton(symbol: "power", title: "Quit Heart Beats", action: #selector(quitClicked))
		let header = NSStackView(views: [tabControl, open, quit])
		header.spacing = 8
		header.alignment = .centerY

		let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
		column.resizingMask = .autoresizingMask
		table.addTableColumn(column)
		table.headerView = nil
		table.backgroundColor = .clear
		table.intercellSpacing = .zero
		table.style = .plain
		table.selectionHighlightStyle = .none
		table.allowsColumnSelection = false
		table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
		table.dataSource = self
		table.delegate = self
		scrollView.documentView = table
		scrollView.drawsBackground = false
		scrollView.hasVerticalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.scrollerStyle = .overlay

		let root = NSView()
		header.translatesAutoresizingMaskIntoConstraints = false
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		root.addSubview(header)
		root.addSubview(scrollView)
		let height = scrollView.heightAnchor.constraint(equalToConstant: Self.rowHeight)
		listHeight = height
		NSLayoutConstraint.activate([
			root.widthAnchor.constraint(equalToConstant: Self.width),
			header.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
			header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
			header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
			scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
			// The rows pad themselves by 8, so their text lines up with the header
			scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 4),
			scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -4),
			scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
			height,
		])
		view = root
		reload()
	}

	override func viewDidLayout() {
		super.viewDidLayout()
		table.sizeLastColumnToFit()
	}

	private func iconButton(symbol: String, title: String, action: Selector) -> NSButton {
		let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage(), target: self, action: action)
		button.bezelStyle = .glass
		button.imagePosition = .imageOnly
		button.toolTip = title
		button.setAccessibilityLabel(title)
		button.widthAnchor.constraint(equalToConstant: 32).isActive = true
		button.heightAnchor.constraint(equalToConstant: 32).isActive = true
		return button
	}

	// MARK: Data

	func apply(_ payload: [[String: Any]]) {
		let new = Dictionary(payload.compactMap { entry -> (String, [Item])? in
			guard let tab = entry["tab"] as? String, let items = entry["items"] as? [[String: Any]] else { return nil }
			return (tab, items.compactMap { item in
				guard let name = item["name"] as? String, let songCount = item["songCount"] as? Int else { return nil }
				return Item(name: name, songCount: songCount, isFavorite: item["isFavorite"] as? Bool ?? false, cover: item["cover"] as? String)
			})
		}, uniquingKeysWith: { _, new in new })
		// Rescans send the same lists again; nothing to redraw then
		guard new != lists else { return }
		let changed = new[tab] != lists[tab]
		lists = new
		if changed {
			reload()
		}
	}

	func addCovers(_ data: [String: Data]) {
		coverData.merge(data) { _, new in new }
		for id in data.keys {
			coverImages.removeObject(forKey: id as NSString)
		}
		guard isViewLoaded else { return }
		// Only the rows on screen draw their cover, so only they refresh
		let visible = table.rows(in: table.visibleRect)
		if visible.length > 0 {
			table.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<visible.location + visible.length), columnIndexes: IndexSet(integer: 0))
		}
	}

	private func coverImage(for id: String?) -> NSImage? {
		guard let id else { return nil }
		if let image = coverImages.object(forKey: id as NSString) {
			return image
		}
		guard let data = coverData[id], let image = NSImage(data: data) else { return nil }
		coverImages.setObject(image, forKey: id as NSString)
		return image
	}

	// MARK: Rows

	private func reload() {
		// Built when the popover first opens
		guard isViewLoaded else { return }
		let current = Self.tabs.first { $0.id == tab }
		if let items = lists[tab], !items.isEmpty {
			let favorites = items.filter(\.isFavorite)
			let others = items.filter { !$0.isFavorite }
			rows = []
			// Years have no favorites, so nothing needs a header there
			if !favorites.isEmpty {
				rows.append(.section("Favorites"))
				rows += favorites.map { .entry($0) }
				if !others.isEmpty {
					rows.append(.section(current?.rest ?? ""))
				}
			}
			rows += others.map { .entry($0) }
		} else {
			rows = [.message(current?.empty ?? "")]
		}
		table.reloadData()
		table.scrollRowToVisible(0)
		listHeight?.constant = min(Self.maximumListHeight, rows.reduce(0) { $0 + height(of: $1) })
		view.layoutSubtreeIfNeeded()
		preferredContentSize = view.fittingSize
	}

	private func height(of row: Row) -> CGFloat {
		if case .section = row {
			return Self.sectionTitleHeight
		}
		return Self.rowHeight
	}

	func numberOfRows(in tableView: NSTableView) -> Int {
		rows.count
	}

	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		height(of: rows[row])
	}

	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		false
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		switch rows[row] {
		case .section(let title):
			let view = tableView.makeView(withIdentifier: SectionTitleView.identifier, owner: nil) as? SectionTitleView ?? SectionTitleView()
			view.title = title
			return view
		case .entry(let item):
			let view = tableView.makeView(withIdentifier: EntryRowView.identifier, owner: nil) as? EntryRowView ?? EntryRowView()
			view.configure(name: item.name, songCount: item.songCount, cover: coverImage(for: item.cover)) { [weak self] in
				self?.play(item.name)
			}
			return view
		case .message(let text):
			let label = NSTextField(labelWithString: text)
			label.textColor = .secondaryLabelColor
			label.alignment = .center
			return label
		}
	}

	// MARK: Actions

	@objc private func tabChanged() {
		tab = Self.tabs[max(0, tabControl.selectedSegment)].id
		reload()
	}

	@objc private func openClicked() {
		open()
	}

	@objc private func quitClicked() {
		quit()
	}
}

private final class SectionTitleView: NSView {
	static let identifier = NSUserInterfaceItemIdentifier("section")

	private let label = NSTextField(labelWithString: "")

	var title: String {
		get { label.stringValue }
		set { label.stringValue = newValue }
	}

	init() {
		super.init(frame: .zero)
		identifier = Self.identifier
		label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .bold)
		label.textColor = .secondaryLabelColor
		label.translatesAutoresizingMaskIntoConstraints = false
		addSubview(label)
		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
			label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
		])
		setAccessibilityRole(.staticText)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) isn't used")
	}
}

/// A row: a cover, a name and how many songs, highlighted under the pointer. A button without the system's look, so the whole row is the target. The table reuses rows, so `configure` sets everything one shows.
private final class EntryRowView: NSView {
	static let identifier = NSUserInterfaceItemIdentifier("entry")

	private let coverView = NSImageView()
	private let nameField = NSTextField(labelWithString: "")
	private let countField = NSTextField(labelWithString: "")
	private var action: () -> Void = {}
	private var hasCover = false
	private var isHovering = false {
		didSet {
			updateHighlight()
		}
	}

	init() {
		super.init(frame: .zero)
		identifier = Self.identifier
		wantsLayer = true
		layer?.cornerRadius = 10
		layer?.cornerCurve = .continuous
		setAccessibilityRole(.button)

		coverView.wantsLayer = true
		coverView.layer?.cornerRadius = 6
		coverView.layer?.cornerCurve = .continuous
		coverView.layer?.masksToBounds = true
		coverView.widthAnchor.constraint(equalToConstant: 32).isActive = true
		coverView.heightAnchor.constraint(equalToConstant: 32).isActive = true
		nameField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
		nameField.lineBreakMode = .byTruncatingTail
		// The name takes the slack, so the counts line up at the trailing edge
		nameField.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
		nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		countField.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
		countField.textColor = .secondaryLabelColor
		countField.setContentHuggingPriority(.required, for: .horizontal)

		let stack = NSStackView(views: [coverView, nameField, countField])
		stack.spacing = 10
		stack.alignment = .centerY
		stack.distribution = .fill
		stack.translatesAutoresizingMaskIntoConstraints = false
		addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
			stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
			stack.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) isn't used")
	}

	func configure(name: String, songCount: Int, cover: NSImage?, action: @escaping () -> Void) {
		self.action = action
		nameField.stringValue = name
		countField.stringValue = songCount.formatted()
		setAccessibilityLabel("\(name), \(songCount) songs")
		hasCover = cover != nil
		coverView.image = cover
		updateCover()
		// A reused row may still be marked from its last use
		isHovering = false
	}

	private func updateCover() {
		if hasCover {
			coverView.imageScaling = .scaleAxesIndependently
			coverView.contentTintColor = nil
			coverView.layer?.backgroundColor = nil
		} else {
			coverView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
			coverView.imageScaling = .scaleProportionallyDown
			coverView.contentTintColor = .secondaryLabelColor
			effectiveAppearance.performAsCurrentDrawingAppearance {
				coverView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
			}
		}
	}

	private func updateHighlight() {
		effectiveAppearance.performAsCurrentDrawingAppearance {
			layer?.backgroundColor = isHovering ? NSColor.labelColor.withAlphaComponent(0.08).cgColor : nil
		}
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		trackingAreas.forEach(removeTrackingArea)
		addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
	}

	override func mouseEntered(with event: NSEvent) {
		isHovering = true
	}

	override func mouseExited(with event: NSEvent) {
		isHovering = false
	}

	override func viewDidChangeEffectiveAppearance() {
		updateHighlight()
		updateCover()
	}

	// The popover isn't the key window, so the first click has to count
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

	override func mouseUp(with event: NSEvent) {
		if bounds.contains(convert(event.locationInWindow, from: nil)) {
			action()
		}
	}

	override func accessibilityPerformPress() -> Bool {
		action()
		return true
	}
}
