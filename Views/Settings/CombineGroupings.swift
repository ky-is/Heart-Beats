import SwiftUI

struct CombineGroupings: View {
	let type: String

	// Stored as plist arrays, which @AppStorage can't read, so this mirrors UserDefaults by hand
	@State private var combined: [[String]] = []

	var body: some View {
		List {
			Section {
				if combined.isEmpty {
					Text("No entries")
						.foregroundStyle(Color.secondaryText)
				} else {
					ForEach(combined, id: \.self) { combineEntries in
						if combineEntries.count == 2 {
							Text("\(combineEntries[0])\(Text(" ← \(combineEntries[1])").foregroundStyle(Color.secondaryText))")
								.accessibilityLabel("\(combineEntries[1]), combined into \(combineEntries[0])")
						}
					}
						.onDelete { offsets in
							withAnimation {
								combined.remove(atOffsets: offsets)
							}
							// The sync observer rescans the collection after this write
							UserDefaults.standard.setCombined(combined, for: type)
						}
				}
			} header: {
				SectionTitle("Existing combinations:")
			}
			Section {
				NavigationLink("Create new") {
					CreateCombineGrouping(type: type)
				}
					.foregroundStyle(.accent)
			}
		}
			.pickerStyle(.wheel)
			.navigationTitle("Combine \(type.capitalized)s")
			.onAppear {
				combined = UserDefaults.standard.combined(for: type)
			}
			// Picks up combinations created in the next screen or synced from another device
			.task {
				for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
					let stored = UserDefaults.standard.combined(for: type)
					if stored != combined {
						withAnimation {
							combined = stored
						}
					}
				}
			}
	}
}

#Preview {
	NavigationStack {
		CombineGroupings(type: "artist")
	}
}
