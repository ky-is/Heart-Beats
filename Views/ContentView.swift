import MediaPlayer
import SwiftUI

struct ContentView: View {
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	@Environment(\.scenePhase) private var scenePhase

	@State private var artistsCollection = GroupedCollection.artists
	@State private var genresCollection = GroupedCollection.genres

	@State private var width: CGFloat = 0
	@State private var leadingInset: CGFloat = 0
	@State private var trailingInset: CGFloat = 0
	/// Counts retaps of each tab, which scroll it to the top
	@State private var scrollToTopRequests: [String: Int] = [:]

	/// Replaced only where the system tab bar would be a centered bottom bar too wide for the songs button to fit beside it. With a column beside the content (the status bar on a foldable's cover screen, or open sideways), the system puts its bar down that side instead, with room to spare.
	private var usesFloatingTabBar: Bool {
#if targetEnvironment(macCatalyst)
		false
#else
		width < FloatingTabBar.widthNeededBesideSystemBar && !hasSideColumn
#endif
	}

	/// A column beside the content (the status bar on a foldable's cover screen, or open sideways), where the system puts a vertical tab bar
	private var hasSideColumn: Bool {
		max(leadingInset, trailingInset) >= 20
	}


	private var yearSuffix: String.SubSequence {
		Calendar.current.component(.year, from: .now).description.suffix(2)
	}

	var body: some View {
		let selectionTabDisabled = Binding {
			selectedTab.isEmpty ? "artists" : selectedTab
		} set: {
			selectedTab = $0.isEmpty ? "artists" : $0
		}
		let showsUnavailable = Binding(get: { artistsCollection.unavailable != nil }, set: { _,_ in artistsCollection.unavailable = nil })
		let tabs = [
			FloatingTab(title: "Artists", systemImage: "music.mic", value: "artists"),
			FloatingTab(title: "Genres", systemImage: "opticaldisc", value: "genres"),
			FloatingTab(title: "Years", systemImage: "\(Int(yearSuffix)! > 50 ? "00" : yearSuffix).square", value: "years"),
		]
		TabView(selection: selectionTabDisabled) {
			Tab(tabs[0].title, systemImage: tabs[0].systemImage, value: tabs[0].value) {
				NavigationContentView {
					MediaList(collection: artistsCollection)
				}
					.environment(\.scrollToTopRequest, scrollToTopRequests[tabs[0].value, default: 0])
			}
			Tab(tabs[1].title, systemImage: tabs[1].systemImage, value: tabs[1].value) {
				NavigationContentView {
					MediaList(collection: genresCollection)
				}
					.environment(\.scrollToTopRequest, scrollToTopRequests[tabs[1].value, default: 0])
			}
			Tab(tabs[2].title, systemImage: tabs[2].systemImage, value: tabs[2].value) {
				NavigationContentView(canToggle: false) {
					YearsList()
				}
					.environment(\.scrollToTopRequest, scrollToTopRequests[tabs[2].value, default: 0])
			}
		}
			.overlay(alignment: .bottomTrailing) {
				// Years ignore the minimum. In a side column it's a nav bar item instead, which the system stacks there with the others.
				if !usesFloatingTabBar && !hasSideColumn && selectedTab != "years" {
					MinimumSongsButton()
						.glassEffect(.regular.interactive(), in: .circle)
						.padding(.trailing, FloatingTabBar.margin)
						.alignedWithSystemTabBar()
				}
			}
			// The system bottom tab bar can't make room for a separate button beside it, so it's replaced
			.safeAreaInset(edge: .bottom, spacing: 0) {
				if usesFloatingTabBar {
					FloatingTabBar(tabs: tabs, selection: selectionTabDisabled) {
						scrollToTopRequests[$0, default: 0] += 1
					}
				}
			}
			.environment(\.usesFloatingTabBar, usesFloatingTabBar)
			.environment(\.showsMinimumInNavigationBar, hasSideColumn && !usesFloatingTabBar)
			.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
			.onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: {
				leadingInset = $0.leading
				trailingInset = $0.trailing
			}
			.onChange(of: scenePhase) { _, newPhase in
				// Picks up ratings changed in Music; skipped when the library is unchanged
				if newPhase == .active {
					GroupedCollection.updateAllIfLibraryChanged()
					YearsCollection.shared.updateIfLibraryChanged(onlyIfScanned: true)
				}
			}
			.alert("Music Unavailable", isPresented: showsUnavailable, actions: {
				Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
			}) {
				let detail: String = switch artistsCollection.unavailable {
				case .restricted:
					"change your library restrictions"
				default:
					"change your permissions"
				}
				Text("Heart Beats requires access to your music library in order to create playlists based on your favorite artists.\n\nPlease \(detail) in the Settings app and try again.")
			}
	}
}

private struct NavigationContentView<Content: View>: View {
	let canToggle: Bool
	let content: () -> Content

	init(canToggle: Bool = true, @ViewBuilder content: @escaping () -> Content) {
		self.canToggle = canToggle
		self.content = content
	}

	@State private var showSettings = false

	@Environment(\.usesFloatingTabBar) private var usesFloatingTabBar
	@Environment(\.showsMinimumInNavigationBar) private var showsMinimumInNavigationBar

	@AppStorage(UserDefaults.Key.listViewMode) private var listViewMode = UserDefaults.standard.listViewMode
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

#if targetEnvironment(simulator)
	private let imageIncrement = 3
	func screenshotImages(startIndex: Int) -> [Image] {
		let idealSize = CGSize(width: 128, height: 128)
		return GroupedCollection.current.entries.filter({ UserDefaults.standard.selectedTab == "genres" ? true : UserDefaults.standard.favorites(for: GroupedCollection.current.groupBy).contains($0.id) })[startIndex..<startIndex+imageIncrement].compactMap { $0.artwork?.image(at: idealSize) }.map { Image(uiImage: $0.scale(to: idealSize)) }
	}
#endif

	var body: some View {
		NavigationStack {
			content()
				.scrollEdgeEffectStyle(.soft, for: .top)
				.toolbarVisibility(usesFloatingTabBar ? .hidden : .automatic, for: .tabBar)
				.toolbar {
#if targetEnvironment(macCatalyst)
					if canToggle {
						ToolbarItem(placement: .principal) {
							MinimumSongsButton()
						}
					}
#endif
#if !targetEnvironment(macCatalyst)
					// Only tabs with the list toggle use the minimum
					if canToggle && showsMinimumInNavigationBar {
						ToolbarItem {
							MinimumSongsButton(isInNavigationBar: true)
						}
					}
#endif
//					ToolbarItemGroup(placement: .topBarTrailing) {
//#if targetEnvironment(simulator) //SAMPLE
//							ShareLink(items: screenshotImages(startIndex: 0)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//							ShareLink(items: screenshotImages(startIndex: imageIncrement)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//							ShareLink(items: screenshotImages(startIndex: imageIncrement * 2)) { SharePreview(MediaCollection.current.groupBy, image: $0) }
//#endif
						if canToggle {
							ToolbarItem {
								Button("Show as \(listViewMode)", systemImage: listViewMode == "grid" ? "list.triangle" : "square.grid.2x2") {
									withAnimation {
										listViewMode = listViewMode == "grid" ? "list" : "grid"
									}
								}
#if targetEnvironment(macCatalyst)
								.buttonStyle(.borderless)
#endif
							}
						}
						ToolbarSpacer(.fixed)
						ToolbarItem {
							Button("Settings", systemImage: "gearshape") {
								showSettings = true
							}
#if targetEnvironment(macCatalyst)
								.buttonStyle(.borderless)
#endif
						}
//					}
				}
#if DEBUG
				.onAppear {
					// Lets screenshot runs open Settings with a launch argument
					if UserDefaults.standard.string(forKey: "debugScreen") == "settings" {
						showSettings = true
					}
				}
#endif
				.sheet(isPresented: $showSettings) {
					SettingsView()
				}
		}
	}
}

private extension EnvironmentValues {
	@Entry var usesFloatingTabBar = false
	@Entry var showsMinimumInNavigationBar = false
}

extension EnvironmentValues {
	/// Increases each time the current tab is tapped again; scroll views jump to the top when it changes
	@Entry var scrollToTopRequest = 0
}

extension View {
	/// Scrolls to the top when the current tab is tapped again, like the system tab bar does.
	func scrollsToTopOnTabRetap() -> some View {
		modifier(ScrollToTopOnTabRetap())
	}
}

private struct ScrollToTopOnTabRetap: ViewModifier {
	@Environment(\.scrollToTopRequest) private var request
	@State private var scrollView = WeakScrollView()
	/// The top inset with the large title showing, the largest it gets
	@State private var expandedTopInset: CGFloat = 0

	func body(content: Content) -> some View {
		content
			.background {
				ScrollViewFinder(found: $scrollView)
			}
			.onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.top } action: { _, inset in
				expandedTopInset = max(expandedTopInset, inset)
			}
			.onChange(of: request) {
				// SwiftUI stops at the content's top edge with the large title still collapsed, so this scrolls the way UIKit's own scroll-to-top does
				guard let scrollView = scrollView.value else { return }
				let top = max(expandedTopInset, scrollView.adjustedContentInset.top)
				scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -top), animated: true)
			}
	}
}

private final class WeakScrollView {
	weak var value: UIScrollView?
}

/// Finds the scroll view this is placed in the background of.
private struct ScrollViewFinder: UIViewRepresentable {
	@Binding var found: WeakScrollView

	func makeUIView(context: Context) -> UIView {
		let view = UIView()
		view.isUserInteractionEnabled = false
		return view
	}

	func updateUIView(_ view: UIView, context: Context) {
		let found = found
		DispatchQueue.main.async {
			guard found.value == nil else { return }
			// The background sits beside the scroll view, so search each ancestor's subtree for the nearest one
			var ancestor = view.superview
			while let current = ancestor {
				if let scrollView = current.firstScrollView(excluding: view) {
					found.value = scrollView
					return
				}
				ancestor = current.superview
			}
		}
	}
}

private extension UIView {
	func firstScrollView(excluding excluded: UIView) -> UIScrollView? {
		var queue = subviews
		while !queue.isEmpty {
			let next = queue.removeFirst()
			if next === excluded {
				continue
			}
			if let scrollView = next as? UIScrollView {
				return scrollView
			}
			queue.append(contentsOf: next.subviews)
		}
		return nil
	}
}

private struct FloatingTab: Identifiable {
	let title: String
	let systemImage: String
	let value: String

	var id: String { value }
}

/// A glass tab bar sized and placed like the system one, which never collapses and has the minimum songs button floating beside it.
private struct FloatingTabBar: View {
	let tabs: [FloatingTab]
	@Binding var selection: String
	let reselect: (String) -> Void

	@Namespace private var namespace

	// Measured from the iOS 27 system tab bar
	static let margin: CGFloat = 20
	static let spacing: CGFloat = 12
	static let circleSize: CGFloat = 62
	/// The centered system bar with these three tabs
	static let systemBarWidth: CGFloat = 266
	/// The narrowest screen where the centered system bar and the songs button don't overlap
	static let widthNeededBesideSystemBar = 2 * (systemBarWidth / 2 + spacing + circleSize + margin)

	private let barHeight: CGFloat = 62
	private let itemSpacing: CGFloat = 85
	/// The selection pill is wider than the spacing between tabs, so it overlaps its neighbors
	private let selectionWidth: CGFloat = 98
	private let inset: CGFloat = 4

	var body: some View {
		GlassEffectContainer(spacing: 0) {
			HStack(spacing: Self.spacing) {
				HStack(spacing: 0) {
					ForEach(tabs) { tab in
						let isSelected = tab.value == selection
						Button {
							if isSelected {
								reselect(tab.value)
							} else {
								withAnimation(.snappy) {
									selection = tab.value
								}
							}
						} label: {
							VStack(spacing: 1) {
								Image(systemName: tab.systemImage)
									.font(.system(size: 24))
									.symbolVariant(.fill)
									.frame(height: 28)
								Text(tab.title)
									.font(.system(size: 10, weight: .semibold))
									.lineLimit(1)
							}
								.frame(width: itemSpacing, height: barHeight - inset * 2)
								.foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
								.background {
									if isSelected {
										Capsule()
											.fill(.quaternary)
											.frame(width: selectionWidth)
											.matchedGeometryEffect(id: "selection", in: namespace)
									}
								}
								.contentShape(.capsule)
						}
							.buttonStyle(.plain)
							.accessibilityAddTraits(isSelected ? [.isSelected] : [])
					}
				}
					.padding(.vertical, inset)
					.padding(.horizontal, inset + (selectionWidth - itemSpacing) / 2)
					.glassEffect(.regular.interactive(), in: .capsule)
					.accessibilityElement(children: .contain)
					.accessibilityAddTraits(.isTabBar)
				// Years ignore the minimum; hidden but still taking its space, so the tabs don't move under a finger
				MinimumSongsButton()
					.glassEffect(.regular.interactive(), in: .circle)
					.opacity(selection == "years" ? 0 : 1)
					.allowsHitTesting(selection != "years")
					.accessibilityHidden(selection == "years")
					.animation(.default, value: selection == "years")
			}
		}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, Self.margin)
			.alignedWithSystemTabBar()
	}
}

private extension View {
	/// Sits as low as the system tab bar does.
	func alignedWithSystemTabBar() -> some View {
		modifier(SystemTabBarBottomPadding())
	}
}

private struct SystemTabBarBottomPadding: ViewModifier {
	/// How far the system bar sits below the bottom safe area edge
	private let dropIntoSafeArea: CGFloat = 13

	@State private var bottomSafeArea: CGFloat = 0

	func body(content: Content) -> some View {
		content
			// Without a home indicator there's no safe area to sit in, so leave a gap instead
			.padding(.bottom, bottomSafeArea > 0 ? -min(dropIntoSafeArea, bottomSafeArea) : 8)
			.onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomSafeArea = $0 }
	}
}

#Preview {
	ContentView()
}
