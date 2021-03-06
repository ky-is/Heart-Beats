import UIKit

final class AddCombineTableViewController: UITableViewController {

	@IBOutlet weak var intoPicker: UIPickerView!
	@IBOutlet weak var fromPicker: UIPickerView!

	var into: String?
	var from: String?

	@IBAction func onSave(_ sender: UIBarButtonItem) {
		guard let into = into, let from = from else {
			return alert("Invalid \(self.into == nil ? "into" : "from") artist", message: "Please select an artist and try again.", cancel: "OK")
		}
		guard into != from else {
			return alert("Invalid artists", message: "Cannot combine identical artist names. Please change one and try again.", cancel: "OK")
		}
		let combine = [ into, from ]
		if Zephyr.shared.userDefaults.showGenres {
			Zephyr.shared.userDefaults.combinedGenres.append(combine)
		} else {
			Zephyr.shared.userDefaults.combined.append(combine)
		}

		onCancel(sender)
	}

	@IBAction func onCancel(_ sender: UIBarButtonItem) {
		dismiss(animated: true, completion: nil)
	}

}

extension AddCombineTableViewController: UIPickerViewDataSource {

	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return SongCollections.shared.allNames.count + 1
	}

}

extension AddCombineTableViewController: UIPickerViewDelegate {

	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return row == 0 ? "" : SongCollections.shared.allNames[row - 1]
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		let artistName = row != 0 ? SongCollections.shared.allNames[row - 1] : nil
		switch pickerView.restorationIdentifier {
		case "INTO":
			into = artistName
		case "FROM":
			from = artistName
		default:
			print("ERR", "Unknown picker", pickerView.restorationIdentifier ?? "")
		}
	}

}
