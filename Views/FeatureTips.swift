import SwiftUI
import TipKit
import WidgetKit

/// Plays since Heart Beats was last opened. The Siri and widget tips show after a few, and hide again when the app is left, so they come and go instead of staying up.
@Observable
final class RecentPlays {
	static let shared = RecentPlays()
	static let tipThreshold = 3

	var count = 0
}

/// Suggests Siri and Shortcuts until they're used to play something.
struct SiriTip: Tip {
	var id: String { "siri" }

	var title: Text {
		Text("Shuffle with Siri")
	}

	var message: Text? {
		let artist = TopPlays.load()?.entries(for: .artist).first?.name
		return Text("Say “Shuffle \(artist ?? "an artist") in Heart Beats,” or add Heart Beats actions in Shortcuts and to the Action button.")
	}

	var image: Image? {
		Image(systemName: "waveform")
	}

	/// Siri or Shortcuts played something, so the tip has done its job.
	static func used() {
		SiriTip().invalidate(reason: .actionPerformed)
	}
}

/// Suggests the widget and control until one is added or tapped.
struct WidgetTip: Tip {
	var id: String { "widget" }

	var title: Text {
		Text("Shuffle in One Tap")
	}

	var message: Text? {
#if targetEnvironment(macCatalyst)
		Text("Add the Most Played widget to your desktop or Notification Center to shuffle your top artists in one click.")
#else
		Text("Add the Most Played widget to your Home Screen or Lock Screen, or the Shuffle control to Control Center, to shuffle your top artists in one tap.")
#endif
	}

	var image: Image? {
		Image(systemName: "square.grid.2x2")
	}

	/// A widget or the control played something, so the tip has done its job.
	static func used() {
		WidgetTip().invalidate(reason: .actionPerformed)
	}

	/// Closes the tip for good once a widget or control is added.
	static func invalidateIfAdded() async {
		var added = (try? await WidgetCenter.shared.currentConfigurations())?.isEmpty == false
#if !targetEnvironment(macCatalyst)
		if !added, let controls = try? await ControlCenter.shared.currentControls() {
			added = !controls.isEmpty
		}
#endif
		if added {
			WidgetTip().invalidate(reason: .actionPerformed)
		}
	}
}

/// The Siri tip, then the widget tip, one at a time above the list, after a few plays since the app was opened.
struct FeatureTipsView: View {
	@State private var tips = TipGroup(.ordered) {
		SiriTip()
		WidgetTip()
	}

	@Environment(\.scenePhase) private var scenePhase

	var body: some View {
		Group {
			if RecentPlays.shared.count < RecentPlays.tipThreshold {
				EmptyView()
			} else if let tip = tips.currentTip as? SiriTip {
				TipView(tip)
			} else if let tip = tips.currentTip as? WidgetTip {
				TipView(tip)
			}
		}
			.padding(.horizontal)
			.task {
				await WidgetTip.invalidateIfAdded()
			}
			.onChange(of: scenePhase) { _, phase in
				if phase == .background {
					RecentPlays.shared.count = 0
				}
			}
	}
}
