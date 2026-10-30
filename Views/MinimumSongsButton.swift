import SwiftUI
import TipKit
import UIKit

/// The minimum actually applied: the stored one, capped to the current library's largest entry.
private func effectiveMinimum(_ minimum: Int, selectedTab: String) -> Int {
	let collection = selectedTab == "genres" ? GroupedCollection.genres : GroupedCollection.artists
	return min(minimum, collection.maximumSongsLimit)
}

/// Changes the minimum by one from the applied value, staying between 1 and the library's largest entry. Returns whether it changed.
@discardableResult
func stepMinimum(by step: Int) -> Bool {
	let defaults = UserDefaults.standard
	let collection = defaults.selectedTab == "genres" ? GroupedCollection.genres : GroupedCollection.artists
	let value = effectiveMinimum(defaults.minimum, selectedTab: defaults.selectedTab)
	let next = value + step
	guard next >= 1, next <= collection.maximumSongsLimit else { return false }
	defaults.minimum = next
	// Closes the tutorial, like a tap on the number
	MinimumSongsTip().invalidate(reason: .actionPerformed)
	return true
}

/// The first-run tutorial for the minimum, pointing at the button
struct MinimumSongsTip: Tip {
	var showsSteppers = false

	var id: String { "minimumSongs" }

	var title: Text {
		Text("Choose Who Shows Up")
	}

	var message: Text? {
		if showsSteppers {
#if targetEnvironment(macCatalyst)
			Text("Artists and genres with fewer songs than this number are hidden. Use − and + to change it.")
#else
			Text("Artists and genres with fewer songs than this number are hidden.")
#endif
		} else {
			Text("Artists and genres with fewer songs than this number are hidden.")
		}
	}

	var image: Image? {
		Image(systemName: "music.note.list")
	}

	/// Off for screenshot runs (the sample library), so it doesn't cover the shots
	static func configure() {
		if !SampleLibrary.isOn {
			try? Tips.configure()
		}
	}
}

struct MinimumSongsButton: View {
	/// A plain nav bar item, which the system styles itself, rather than the floating circle
	var isInNavigationBar = false

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.legibilityWeight) private var legibilityWeight

	@State private var showSongMinimum = false
	@State private var isHovering = false
	@State private var tappedExplanation = false
	/// The first-run tip, drawn as a bubble above the button rather than a popover, so the button stays tappable under it
	@State private var showsTip = false
	/// Set by a click that hides the bubble while hovering, until the pointer leaves
	@State private var hoverSuppressed = false

#if targetEnvironment(macCatalyst)
	/// On a Mac the button sits at the window's bottom edge, so the popover opens upward instead of off the window
	private static let popoverArrowEdge: Edge? = .bottom
#else
	/// The system picks, which puts it above the bar. An arrow on top would place it below the button, where there's no room, so it covers the button instead.
	private static let popoverArrowEdge: Edge? = nil
#endif
#if DEBUG
	private static var openedDebugPopover = false
#endif

	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	/// With room to spare, the +/- buttons sit beside the number instead of in a popover
	private var showsSteppers: Bool {
		!isInNavigationBar && horizontalSizeClass == .regular
	}

	var body: some View {
		if showsSteppers {
			expanded
		} else {
			collapsed
		}
	}

	private var expanded: some View {
		let value = effectiveMinimum(minimum, selectedTab: selectedTab)
		return HStack(spacing: 0) {
			MinimumSongsStepButton(step: -1, onStep: closeExplanation)
				.frame(width: 48, height: 62)
			Button {
				// Toggles the tutorial; the first-run one counts as seen once it's closed this way
				if showsExplanation {
					closeExplanation()
				} else {
					tappedExplanation = true
				}
			} label: {
				Text(String(value))
					.font(.system(size: 24, weight: .bold))
					.monospacedDigit()
					.frame(minWidth: 36, minHeight: 62)
					.contentShape(.rect)
					.foregroundStyle(.tint)
			}
				.buttonStyle(.plain)
				.accessibilityLabel("Minimum songs")
				.accessibilityValue("song".pluralize(value))
				.accessibilityHint("Shows what the minimum does")
				.accessibilityAdjustableAction(adjust)
				.accessibilityInputLabels(["Minimum", "Minimum songs", "Songs"])
				// Only the number shows the tutorial on hover, not the +/- buttons beside it
				.onHover {
					isHovering = $0
					if !$0 {
						hoverSuppressed = false
					}
				}
			MinimumSongsStepButton(step: 1, onStep: closeExplanation)
				.frame(width: 48, height: 62)
		}
			.imageScale(.large)
			.padding(.horizontal, 4)
			// One glass capsule around the number and both steppers, on the Mac too
			.glassEffect(.regular.interactive(), in: .capsule)
			// A bubble rather than a popover, so it doesn't catch the next tap on the +/- buttons
			.overlay(alignment: .bottomTrailing) {
				if showsExplanation {
					// Shown only by hovering, it catches no clicks, so the pointer can move on to the buttons below
					let hoverOnly = isHovering && !showsTip && !tappedExplanation
					tipBubble(MinimumSongsTip(showsSteppers: true), canClose: !hoverOnly)
						.allowsHitTesting(!hoverOnly)
				}
			}
			.animation(.snappy, value: showsExplanation)
			.task { await followTip() }
	}

	private var collapsed: some View {
		let value = effectiveMinimum(minimum, selectedTab: selectedTab)
		return Group {
			if isInNavigationBar {
				// The number is drawn as an image, so the system still moves it into a side column with the other nav bar items (it leaves text-only ones up top)
				Button {
					showSongMinimum = true
				} label: {
					Label {
						Text(String(value))
					} icon: {
						Image(uiImage: .number(value, heavier: legibilityWeight == .bold))
					}
				}
					// The number is an image of a fixed size, so a long press at large text sizes shows it enlarged
					.accessibilityShowsLargeContentViewer {
						Label("Minimum songs: \(value)", systemImage: "music.note.list")
					}
			} else {
				Button {
					showSongMinimum = true
				} label: {
					Text(String(value))
						.font(.system(size: 24, weight: .bold))
						.frame(width: 62, height: 62)
						.contentShape(.circle)
						.foregroundStyle(.tint)
				}
					.buttonStyle(.plain)
					// Fixed-size like the tab bar beside it, so a long press at large text sizes shows it enlarged
					.accessibilityShowsLargeContentViewer {
						Label("Minimum songs: \(value)", systemImage: "music.note.list")
					}
			}
		}
			.accessibilityLabel("Minimum songs")
			.accessibilityValue("song".pluralize(value))
			.accessibilityHint("Shows buttons to change it")
			.accessibilityAdjustableAction(adjust)
			.accessibilityInputLabels(["Minimum", "Minimum songs", "Songs"])
#if DEBUG
			.onAppear {
				// Lets screenshot runs open the popover with a launch argument, until it has shown once like a tap, so a hinge move doesn't open it again from the moved button
				if UserDefaults.standard.string(forKey: "debugScreen") == "minimum" && !Self.openedDebugPopover {
					// A bottom bar item is rebuilt after it first appears, so the popover waits for the button that stays
					Task {
						try? await Task.sleep(for: .seconds(0.5))
						if !Self.openedDebugPopover {
							showSongMinimum = true
						}
					}
				}
			}
#endif
			// A toolbar item can't draw outside itself, so there it's a popover
			.popoverTip(isInNavigationBar ? MinimumSongsTip() : nil, arrowEdge: Self.popoverArrowEdge)
			.onChange(of: showSongMinimum) {
				if showSongMinimum {
					MinimumSongsTip().invalidate(reason: .actionPerformed)
				}
			}
			.popover(isPresented: $showSongMinimum, arrowEdge: Self.popoverArrowEdge) {
				MinimumSongsStepper(showsValue: isInNavigationBar)
#if DEBUG
					.onAppear { Self.openedDebugPopover = true }
#endif
					.task { await SampleLibrary.ready("minimum") }
			}
			// After the popover, so it opens above the button rather than growing out of the glass over the tab bar
			.modifier(FloatingGlass(isOn: !isInNavigationBar, shape: .circle))
			.overlay(alignment: .bottomTrailing) {
				if showsTip && !isInNavigationBar {
					tipBubble(MinimumSongsTip(), canClose: true)
				}
			}
			.task {
				if !isInNavigationBar {
					await followTip()
				}
			}
	}

	/// VoiceOver's swipe up and down, which step the minimum without opening the buttons
	private func adjust(_ direction: AccessibilityAdjustmentDirection) {
		switch direction {
		case .increment:
			stepMinimum(by: 1)
		case .decrement:
			stepMinimum(by: -1)
		default:
			break
		}
	}

	/// Closes the tutorial (the first-run tip for good), and keeps hovering from bringing it straight back
	private func closeExplanation() {
		MinimumSongsTip().invalidate(reason: .actionPerformed)
		tappedExplanation = false
		hoverSuppressed = isHovering
	}

	/// The tutorial: the first-run tip, or reopened by clicking the number
	private var showsExplanation: Bool {
		showsTip || tappedExplanation || (isHovering && !hoverSuppressed)
	}

	/// The tip's text in a bubble above the button, trailing-aligned with it. Unlike a popover it leaves the button below tappable, and a tap there closes the tip for good.
	private func tipBubble(_ tip: MinimumSongsTip, canClose: Bool) -> some View {
		HStack(alignment: .top, spacing: 12) {
			tip.image?
				.font(.title2)
				.foregroundStyle(.tint)
			VStack(alignment: .leading, spacing: 4) {
				tip.title
					.font(.headline)
				tip.message?
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity, alignment: .leading)
			if canClose {
				Button("Close", systemImage: "xmark") {
					tip.invalidate(reason: .tipClosed)
					tappedExplanation = false
				}
					.labelStyle(.iconOnly)
					.font(.footnote.bold())
					.foregroundStyle(.secondary)
					.buttonStyle(.plain)
			}
		}
			.padding()
			.frame(width: 320)
			.glassEffect(.regular, in: .rect(cornerRadius: 24))
			.offset(y: -(12 + 62))
			.transition(reduceMotion ? AnyTransition.opacity : .opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
	}

	private func followTip() async {
		for await shouldDisplay in MinimumSongsTip().shouldDisplayUpdates {
			withAnimation(.snappy) {
				showsTip = shouldDisplay
			}
		}
	}
}

private struct FloatingGlass<S: Shape>: ViewModifier {
	let isOn: Bool
	let shape: S

	func body(content: Content) -> some View {
#if targetEnvironment(macCatalyst)
		content
#else
		if isOn {
			content.glassEffect(.regular.interactive(), in: shape)
		} else {
			content
		}
#endif
	}
}

private struct MinimumSongsExplanation: View {
	var body: some View {
		Text("Minimum number of songs an artist/genre needs to be displayed")
			.fixedSize(horizontal: false, vertical: true)
	}
}

/// Steps from the applied value, so a stored minimum above the library's largest entry doesn't make taps look ignored
private struct MinimumSongsStepButton: View {
	let step: Int
	var onStep: () -> Void = {}

	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	var body: some View {
		let collection = selectedTab == "genres" ? GroupedCollection.genres : GroupedCollection.artists
		let value = effectiveMinimum(minimum, selectedTab: selectedTab)
		// 0 isn't a valid minimum: the stored value treats it as unset (15)
		let isDisabled = step < 0 ? value <= 1 : value >= collection.maximumSongsLimit
		Button {
			stepMinimum(by: step)
			onStep()
		} label: {
			Label(step < 0 ? "Fewer songs" : "More songs", systemImage: step < 0 ? "minus" : "plus")
				.labelStyle(.iconOnly)
				.bold()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.contentShape(.rect)
				.foregroundStyle(.tint)
				.opacity(isDisabled ? 0.3 : 1)
		}
			// Plain, so the Mac doesn't give each its own bordered background sized to its symbol
			.buttonStyle(.plain)
			.disabled(isDisabled)
			.accessibilityInputLabels(step < 0 ? ["Minus", "Fewer", "Fewer songs"] : ["Plus", "More", "More songs"])
	}
}

struct MinimumSongsStepper: View {
	/// The number between the buttons, for when the popover covers the button that shows it (a side column's)
	var showsValue = false

	@AppStorage(UserDefaults.Key.minimum) private var minimum = UserDefaults.standard.minimum
	@AppStorage(UserDefaults.Key.selectedTab) private var selectedTab = "artists"

	var body: some View {
		HStack {
			MinimumSongsExplanation()
				.font(.footnote)
				.padding([.leading, .vertical])
			MinimumSongsStepButton(step: -1)
				.frame(width: 40, height: 40)
			if showsValue {
				let value = effectiveMinimum(minimum, selectedTab: selectedTab)
				Text(String(value))
					.font(.title2.bold())
					.monospacedDigit()
					.foregroundStyle(.tint)
					.frame(minWidth: 36)
					.contentTransition(.numericText(value: Double(value)))
					.animation(.snappy, value: value)
					.accessibilityLabel("Minimum songs")
					.accessibilityValue("song".pluralize(value))
			}
			MinimumSongsStepButton(step: 1)
				.frame(width: 40, height: 40)
		}
			.imageScale(.large)
			.presentationCompactAdaptation(.popover)
#if targetEnvironment(macCatalyst)
			.padding(.horizontal)
#endif
	}
}

#Preview {
	MinimumSongsButton()
		.popover(isPresented: .constant(true)) {
			MinimumSongsStepper()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.fontDesign(.rounded)
}

private extension UIImage {
	/// A bold accent-colored number the size of a nav bar item's glass, for a button whose number is the point
	/// `heavier` follows the Bold Text setting, which an image doesn't pick up by itself.
	static func number(_ value: Int, heavier: Bool = false) -> UIImage {
		let descriptor = UIFont.systemFont(ofSize: 24, weight: heavier ? .heavy : .bold).fontDescriptor.withDesign(.rounded)!
		let text = NSAttributedString(string: String(value), attributes: [.font: UIFont(descriptor: descriptor, size: 24), .foregroundColor: UIColor(named: "AccentColor") ?? .tintColor])
		let size = text.size()
		return UIGraphicsImageRenderer(size: CGSize(width: ceil(size.width), height: ceil(size.height))).image { _ in
			text.draw(at: .zero)
		}
			.withRenderingMode(.alwaysOriginal)
	}
}
