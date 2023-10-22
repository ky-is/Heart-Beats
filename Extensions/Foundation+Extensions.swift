import Foundation

extension Bundle {
	var version: String {
		return infoDictionary!["CFBundleShortVersionString"] as! String
	}
}

extension String {
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
