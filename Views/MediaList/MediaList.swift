import SwiftUI
import MediaPlayer
import os

typealias ListGroupEntry = (label: String?, entries: [MediaEntry])

struct MediaList: View {
	var collection: GroupedCollection

	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?
	@State private var pendingPlay: PendingPlay?
	/// The entry played last, which VoiceOver returns to when Music hands back
	@State private var lastPlayedID: String?
	@AccessibilityFocusState private var focusedEntry: String?
	@Namespace private var rotorNamespace

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode
	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"
	/// When the minimum last changed, so the rescan it causes is announced but other rescans aren't
	@State private var minimumChangedAt: Date?

	private func play(entry: MediaEntry, addToQueue: Bool) {
		guard let songs = entry.songs else {
			pendingPlay = PendingPlay(id: entry.id, addToQueue: addToQueue)
			return
		}

		lastPlayedID = entry.id
		recordPlay(of: entry.id, kind: collection.groupBy == "genre" ? .genre : .artist)
		playSongs(songs, addToQueue: addToQueue)
	}

	var body: some View {
		let activeSelection = Binding {
			selection
		} set: { newValue in
			withAnimation {
				selection = newValue
			}
			if let newValue {
				play(entry: newValue, addToQueue: false)
			}
		}
//		let allEntriesGroups: [ListGroupEntry] = [(nil, [])] //SAMPLE
		let allEntriesGroups = collection.sections
		let hasEntries = !collection.entries.isEmpty
		let showHeaders = SampleLibrary.isOn ? false : allEntriesGroups.count > 1
		let entryCount = SampleLibrary.isOn ? 42 : collection.entries.count
		let gettingStarted = collection.gettingStarted
		Group {
			if !hasEntries {
				EmptyMediaList(collection: collection, listViewMode: listViewMode, imageWidth: 88)
			} else if listViewMode == "grid" {
				GridView(groupBy: collection.groupBy, showHeaders: showHeaders, largeTitles: false, gettingStarted: gettingStarted, allEntriesGroups: allEntriesGroups, activeSelection: activeSelection, focusedEntry: $focusedEntry, rotorNamespace: rotorNamespace, play: play)
			} else {
				ListView(groupBy: collection.groupBy, showHeaders: showHeaders, gettingStarted: gettingStarted, allEntriesGroups: allEntriesGroups, activeSelection: activeSelection, focusedEntry: $focusedEntry, rotorNamespace: rotorNamespace, play: play)
			}
		}
			.opensFavoriteSongs()
			.favoritesRotor(allEntriesGroups.first { $0.label == FavoritesLabel }?.entries ?? [], in: rotorNamespace)
			.navigationTitle(collection.groupBy.capitalized.pluralize(entryCount))
			.playWhenLoaded($pendingPlay, entries: collection.entries, play: play)
			.task { await SampleLibrary.ready(collection.groupBy) }
			.onChange(of: minimum) {
				minimumChangedAt = .now
			}
			.onChange(of: collection.entries.count) { _, count in
				announceShown(count)
			}
			.onChange(of: scenePhase) { _, newPhase in
				// ContentView rescans the library on foreground
				if newPhase == .active {
					withAnimation {
						selection = nil
					}
					// Once, so a later return to the app starts where VoiceOver normally would
					restoreFocus(to: lastPlayedID, focus: $focusedEntry)
					lastPlayedID = nil
				}
			}
	}
}

private extension MediaList {
	/// VoiceOver already reads the new minimum; this says what it did to the list
	func announceShown(_ count: Int) {
		guard selectedTab == "\(collection.groupBy)s", let changedAt = minimumChangedAt, Date.now.timeIntervalSince(changedAt) < 5 else { return }
		minimumChangedAt = nil
		AccessibilityNotification.Announcement("\(collection.groupBy.capitalized.pluralize(count)) shown").post()
	}
}

private extension View {
	/// Jumps straight to each favorite, from VoiceOver's rotor
	func favoritesRotor(_ favorites: [MediaEntry], in namespace: Namespace.ID) -> some View {
		accessibilityRotor("Favorites") {
			ForEach(favorites) { entry in
				AccessibilityRotorEntry(Text(entry.id), id: entry.id, in: namespace)
			}
		}
	}
}

/// Puts VoiceOver back on the entry that was played, rather than the top of the screen, once the app is back from Music.
func restoreFocus(to id: String?, focus: AccessibilityFocusState<String?>.Binding) {
	guard let id else { return }
	Task {
		// VoiceOver picks its own element as the app comes back, so this follows it
		try? await Task.sleep(for: .seconds(0.5))
		focus.wrappedValue = id
	}
}

struct GridView: View {
	let groupBy: String?
	let showHeaders: Bool
	let largeTitles: Bool
	/// Shows Getting Started above the entries
	var gettingStarted: GettingStarted? = nil
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	var focusedEntry: AccessibilityFocusState<String?>.Binding
	let rotorNamespace: Namespace.ID
	let play: (MediaEntry, Bool) -> Void

	/// Also how far a header is inset to line up with the first column's artwork
	static let spacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8

	private func sizeColumns(in geometry: GeometryProxy, spacing: CGFloat) -> (count: Int, width: CGFloat) {
		let idealWidth: CGFloat = geometry.size.width >= 2048 ? 256 : (UIDevice.current.userInterfaceIdiom == .pad ? 176 : 144)
		guard geometry.size.width > 0 else {
			return (3, idealWidth)
		}
		let columnCount = max(1, (geometry.size.width / (idealWidth + spacing * 2)).rounded(.down))
		let columnWidth = geometry.size.width / columnCount - spacing * 1
		return (Int(columnCount), columnWidth)
	}

	var body: some View {
		GeometryReader { geometry in
			let (columnCount, columnSize) = sizeColumns(in: geometry, spacing: Self.spacing)
			ScrollView {
				if let gettingStarted {
					GettingStartedCard(state: gettingStarted)
						.padding(.horizontal, Self.spacing * 2)
						.padding(.top, Self.spacing)
				}
				LazyVGrid(columns: Array(repeating: GridItem(.fixed(columnSize), spacing: Self.spacing, alignment: .top), count: columnCount), spacing: Self.spacing * 1.5) {
					EntriesView(groupBy: groupBy, listViewMode: "grid", largeTitles: largeTitles, imageWidth: columnSize - Self.spacing, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: $activeSelection, focusedEntry: focusedEntry, rotorNamespace: rotorNamespace, play: play)
				}
					.padding(.vertical, Self.spacing / 2)
			}
				.scrollsToTopOnTabRetap()
		}
	}
}

private struct ListView: View {
	let groupBy: String
	let showHeaders: Bool
	let gettingStarted: GettingStarted?
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	var focusedEntry: AccessibilityFocusState<String?>.Binding
	let rotorNamespace: Namespace.ID
	let play: (MediaEntry, Bool) -> Void

	/// Keeps each song count near its name on wide screens and windows, with blank sides beyond it
	static let centeredMaxRowWidth: CGFloat = 640
	/// Narrower beside a side column, where the rows sit against the title rather than in the middle
	static let leadingMaxRowWidth: CGFloat = 512

	@State private var margins = EdgeInsets()

	/// Centered unless a column beside the content (like a foldable's status bar) makes the sides uneven, where rows stay lined up with the title
	private static func margins(width: CGFloat, safeArea: EdgeInsets) -> EdgeInsets {
		let centers = safeArea.leading == safeArea.trailing
		let spareWidth = max(0, width - (centers ? centeredMaxRowWidth : leadingMaxRowWidth))
		return EdgeInsets(top: 0, leading: centers ? spareWidth / 2 : 0, bottom: 0, trailing: centers ? spareWidth / 2 : spareWidth)
	}

	var body: some View {
		List(selection: $activeSelection) {
			if let gettingStarted {
				GettingStartedCard(state: gettingStarted)
					.listRowSeparator(.hidden)
					.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
					.selectionDisabled()
			}
			EntriesView(groupBy: groupBy, listViewMode: "list", largeTitles: false, imageWidth: 128, showHeaders: showHeaders, allEntriesGroups: allEntriesGroups, activeSelection: $activeSelection, focusedEntry: focusedEntry, rotorNamespace: rotorNamespace, play: play)
		}
			.listStyle(.plain)
			// Margins rather than a frame, so the list still scrolls from anywhere across the screen
			.contentMargins(.horizontal, margins, for: .scrollContent)
			.onGeometryChange(for: EdgeInsets.self) { Self.margins(width: $0.size.width, safeArea: $0.safeAreaInsets) } action: { margins = $0 }
			.scrollsToTopOnTabRetap()
	}
}

private struct EntriesView: View {
	let groupBy: String?
	let listViewMode: String
	let largeTitles: Bool
	let imageWidth: CGFloat
	let showHeaders: Bool
	let allEntriesGroups: [ListGroupEntry]
	@Binding var activeSelection: MediaEntry?
	var focusedEntry: AccessibilityFocusState<String?>.Binding
	let rotorNamespace: Namespace.ID
	let play: (MediaEntry, Bool) -> Void

	var body: some View {
		ForEach(allEntriesGroups, id: \.label) { listGroup in
			Section {
				let inFavorites = listGroup.label == FavoritesLabel
				// A row rather than the section's header, which a list always pins to the top
				if showHeaders && listViewMode == "list" {
					SectionHeader(title: listGroup.label ?? "Uncategorized")
						.listRowSeparator(.hidden)
						.selectionDisabled()
				}
				ForEach(listGroup.entries) { entry in
					if listViewMode == "grid" {
						Button {
							activeSelection = entry
						} label: {
							MediaListEntry(groupBy: groupBy, listViewMode: listViewMode, largeTitles: largeTitles, entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
						}
							.buttonStyle(.plain)
							.accessibilityFocused(focusedEntry, equals: entry.id)
							.accessibilityRotorEntry(id: entry.id, in: rotorNamespace)
					} else {
						MediaListEntry(groupBy: groupBy, listViewMode: listViewMode, largeTitles: largeTitles, entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
							.tag(entry)
							.accessibilityFocused(focusedEntry, equals: entry.id)
							.accessibilityRotorEntry(id: entry.id, in: rotorNamespace)
					}
				}
			} header: {
				// A grid's headers don't pin, so they stay headers there, lined up with the artwork
				if showHeaders && listViewMode == "grid" {
					SectionHeader(title: listGroup.label ?? "Uncategorized")
						.padding(.leading, GridView.spacing)
				}
			}
		}
	}
}

/// A group's name above its entries, scrolling away with them
private struct SectionHeader: View {
	let title: String

	var body: some View {
		Text(title)
			.font(.headline)
			.frame(maxWidth: .infinity, alignment: .leading)
			.accessibilityAddTraits(.isHeader)
	}
}

/// An entry tapped while the list still shows cached entries, which have no songs until the first scan finishes.
struct PendingPlay: Equatable {
	let id: String
	let addToQueue: Bool
}

extension View {
	/// Plays the pending entry once a scan loads its songs.
	func playWhenLoaded(_ pending: Binding<PendingPlay?>, entries: [MediaEntry], play: @escaping (MediaEntry, Bool) -> Void) -> some View {
		onChange(of: entries) { _, entries in
			guard let request = pending.wrappedValue, let entry = entries.first(where: { $0.id.normalized() == request.id.normalized() }), entry.songs != nil else { return }
			pending.wrappedValue = nil
			play(entry, request.addToQueue)
		}
	}
}

/// Plays the songs shuffled in the system player, then opens Music (on iPhone and iPad only when `opensMusic`).
func playSongs(_ songs: [MPMediaItem], addToQueue: Bool, opensMusic: Bool = true) {
	let songCollection = MPMediaItemCollection(items: songs.shuffled())
#if targetEnvironment(macCatalyst)
	MacPlayback.play(songCollection, addToQueue: addToQueue)
#else
	let player = MPMusicPlayerController.systemMusicPlayer
	enqueue(songCollection, on: player, addToQueue: addToQueue)
	player.play()
	guard opensMusic else { return }
	Task {
		guard let url = URL(string: "audio-player-event:"), await UIApplication.shared.open(url) else {
			log.error("Unable to open Music.app")
			return
		}
	}
#endif
}

nonisolated private func enqueue(_ songs: MPMediaItemCollection, on player: MPMusicPlayerController, addToQueue: Bool) {
	if addToQueue {
		player.prepend(MPMusicPlayerMediaItemQueueDescriptor(itemCollection: songs))
	} else {
		player.setQueue(with: songs)
	}
}

#if targetEnvironment(macCatalyst)
/// The player finds Music by its bundle ID, which a stand-in can also claim (like Music Decoy, which keeps the Play key from
/// opening Music); then it's the stand-in that gets started, it never answers, and each player call waits on it. So Music is
/// opened first by its music: link, which only the real app handles, and the player runs off the main thread with a
/// deadline, so a Music that doesn't answer leaves the window responsive and says so.
///
/// Music takes player connections only a few seconds after it launches, once it has restored its queue, and one made
/// before then (even to read the player's state) stalls for 10 s. Nothing says when it's ready, so Heart Beats starts Music
/// in the background when it opens, which has it ready by the time an artist is picked, and a tap waits out what's left of
/// those first seconds.
enum MacPlayback {
	private static let queue = DispatchQueue(label: "is.ky.Heart-Beats.playback")
	private static let deadline: Duration = .seconds(20)
	/// How long after launch Music takes connections: 3.7-5.2 s here (an M-series MacBook Pro, 13,000 songs), with margin
	private static let readyAfterLaunch: TimeInterval = 6

	/// Starts Music hidden in the background, unless it's running.
	static func prewarm() {
		guard runningMusic() == nil, let workspace = (NSClassFromString("NSWorkspace") as? NSObject.Type)?.value(forKey: "sharedWorkspace") as? NSObject, let configuration = (NSClassFromString("NSWorkspaceOpenConfiguration") as? NSObject.Type)?.init() else { return }
		configuration.setValue(false, forKey: "activates")
		configuration.setValue(true, forKey: "hides")
		configuration.setValue(false, forKey: "addsToRecentItems")
		unsafe unsafeBitCast(workspace, to: Workspace.self).openApplication(at: URL(fileURLWithPath: "/System/Applications/Music.app"), configuration: configuration) { _, error in
			if let error {
				log.error("Couldn't start Music: \(error.localizedDescription, privacy: .public)")
			}
		}
		log.notice("Starting Music in the background")
	}

	static func play(_ songs: MPMediaItemCollection, addToQueue: Bool) {
		Task {
			let tapped = ContinuousClock.now
#if DEBUG
			// Mac checks open nothing in front of what the user is doing (see debugPlayIfAsked)
			let opensMusic = UserDefaults.standard.string(forKey: "debugPlay") == nil
#else
			let opensMusic = true
#endif
			if opensMusic, let url = URL(string: "music://"), !(await UIApplication.shared.open(url)) {
				log.error("Unable to open Music")
			}
			await waitUntilMusicIsReady()
			let songs = UncheckedSendable(value: songs)
			let played = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
				let pending = OSAllocatedUnfairLock<CheckedContinuation<Bool, Never>?>(initialState: continuation)
				let finish: @Sendable (Bool) -> Void = { result in pending.withLock { $0.take() }?.resume(returning: result) }
				queue.async {
					let player = MPMusicPlayerController.applicationMusicPlayer
					enqueue(songs.value, on: player, addToQueue: addToQueue)
					player.play()
					finish(true)
				}
				Task {
					try? await Task.sleep(for: deadline)
					finish(false)
				}
			}
			if played {
				log.notice("Playing \(songs.value.count) songs, \(ContinuousClock.now - tapped, privacy: .public) after the tap")
			} else {
				log.error("Music didn't answer within \(deadline, privacy: .public)")
				showMusicNotAnswering()
			}
		}
	}

	/// The real Music (not a stand-in with its bundle ID), if it's running. NSRunningApplication and NSWorkspace are AppKit,
	/// which a Mac Catalyst app has loaded but can't name, so they're looked up at run time.
	private static func runningMusic() -> NSObject? {
		guard let runningApplication = NSClassFromString("NSRunningApplication") as? NSObject.Type, let apps = unsafe runningApplication.perform(NSSelectorFromString("runningApplicationsWithBundleIdentifier:"), with: "com.apple.Music")?.takeUnretainedValue() as? [NSObject] else { return nil }
		return apps.first { ($0.value(forKey: "bundleURL") as? URL)?.path.hasPrefix("/System/") == true }
	}

	/// Waits for Music to be running (it may only just have been opened), then until it's been up long enough to take
	/// connections.
	private static func waitUntilMusicIsReady() async {
		let start = ContinuousClock.now
		var launched: Date?
		while launched == nil, ContinuousClock.now - start < .seconds(10) {
			launched = runningMusic()?.value(forKey: "launchDate") as? Date
			if launched == nil {
				try? await Task.sleep(for: .milliseconds(100))
			}
		}
		guard let launched else {
			log.error("Music didn't start within 10 s")
			return
		}
		let wait = readyAfterLaunch + launched.timeIntervalSinceNow
		log.notice("Music launched \(-launched.timeIntervalSinceNow, privacy: .public) s ago, waiting \(max(0, wait), privacy: .public) s")
		if wait > 0 {
			try? await Task.sleep(for: .seconds(wait))
		}
	}

	private static func showMusicNotAnswering() {
		let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
		guard var controller = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController else { return }
		while let presented = controller.presentedViewController {
			controller = presented
		}
		let alert = UIAlertController(title: "Music Isn't Answering", message: "Open Music, then try again. If another app stands in for Music (like Music Decoy), quit it first.", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		controller.present(alert, animated: true)
	}
}

/// NSWorkspace's way to open an app without bringing it forward
@objc private protocol Workspace {
	@objc(openApplicationAtURL:configuration:completionHandler:)
	func openApplication(at url: URL, configuration: NSObject, completionHandler: (@Sendable (NSObject?, (any Error)?) -> Void)?)
}

nonisolated private struct UncheckedSendable<Value>: @unchecked Sendable {
	let value: Value
}
#endif

#Preview {
	NavigationStack {
		MediaList(collection: GroupedCollection(groupBy: "artist"))
	}
		.fontDesign(.rounded)
}
