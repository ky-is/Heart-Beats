import AppIntents

extension WidgetShuffleIntent {
	/// Never runs: the system runs audio playback intents in the app (see LibraryIntents in the app)
	func perform() async throws -> some IntentResult {
		.result()
	}
}
