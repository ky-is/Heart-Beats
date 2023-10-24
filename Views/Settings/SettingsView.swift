import SwiftUI

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				Section("Manage groupings") {
					NavigationLink {
						CombineGroupings(type: "artist")
					} label: {
						Label("Combine Artists", systemImage: "music.mic")
					}
					NavigationLink {
						CombineGroupings(type: "genre")
					} label: {
						Label("Combine Genres", systemImage: "opticaldisc.fill")
					}
				}
				Section {
					ExternalLink(title: "Review Heart Beats", systemImage: "star.circle.fill", urlPath: "itms-apps://itunes.apple.com/app/id1415282075?action=write-review")
					ExternalLink(title: "View Source", systemImage: "cat.circle.fill", urlPath: "https://github.com/ky-is/Heart-Beats")
				} header: {
					Text("Heart Beats")
				} footer: {
					Text("v\(Bundle.main.version) by Kyle Coburn")
				}
			}
				.navigationTitle("Settings")
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						Button("Close") {
							dismiss()
						}
					}
				}
		}
	}
}

private struct ExternalLink: View {
	let title: String
	let systemImage: String
	let urlPath: String

	var body: some View {
		Link(destination: URL(string: urlPath)!) {
			HStack {
				Label(title, systemImage: systemImage)
				Spacer()
				Image(systemName: "rectangle.portrait.and.arrow.right")
					.imageScale(.small)
					.fontWeight(.semibold)
					.foregroundStyle(Color.tertiary)
					.frame(width: 8)
			}
		}
	}
}

#Preview {
	SettingsView()
		.tint(.accent)
		.fontDesign(.rounded)
}
