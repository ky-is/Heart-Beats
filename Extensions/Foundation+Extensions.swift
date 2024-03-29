import Foundation

extension Bundle {
	var version: String {
		return infoDictionary!["CFBundleShortVersionString"] as! String
	}
}

extension String {
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

extension Array: RawRepresentable where Element: Codable {
	public init?(rawValue: String) {
		guard let data = rawValue.data(using: .utf8),
			  let result = try? JSONDecoder().decode([Element].self, from: data)
		else {
			return nil
		}
		self = result
	}

	public var rawValue: String {
		guard let data = try? JSONEncoder().encode(self),
			  let result = String(data: data, encoding: .utf8)
		else {
			return "[]"
		}
		return result
	}
}
