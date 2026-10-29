import Foundation
import os

nonisolated let log = Logger(subsystem: "is.ky.Heart-Beats", category: "app")
/// Marks library scans and artwork decoding as Points of Interest in Instruments.
nonisolated let signposter = OSSignposter(subsystem: "is.ky.Heart-Beats", category: .pointsOfInterest)

extension Bundle {
	var version: String {
		return infoDictionary!["CFBundleShortVersionString"] as! String
	}
}

nonisolated extension String {
	/// Lowercased and trimmed, for matching names regardless of case.
	func normalized() -> Self {
		lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
	}

	func plural(_ amount: Int) -> String {
		return amount == 1 ? self : "\(self)s"
	}
	func pluralize(_ amount: Int) -> String {
		return "\(amount) \(plural(amount))"
	}

	var forSorting: String {
		let result = lowercased()
		return result.starts(with: "the ") ? String(result.dropFirst(4)) : result
	}
}

nonisolated extension Sequence<String> {
	/// Whether any element matches the name, ignoring case.
	func containsNormalized(_ name: String) -> Bool {
		let target = name.normalized()
		return contains { $0.normalized() == target }
	}
}
