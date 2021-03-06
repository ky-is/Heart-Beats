import UIKit

final class SettingsTableViewController: UITableViewController {

	@IBOutlet weak var rateCell: UITableViewCell!
	@IBOutlet weak var restoreCell: UITableViewCell!

	override func viewDidLoad() {
		restoreCell.isHidden = true //TODO iap
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.purchased), options: [.new], context: nil)
	}

	deinit {
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.purchased))
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		unlockedPurchase()
	}

	private func unlockedPurchase() {
		restoreCell.accessoryType = .checkmark
		restoreCell.textLabel?.text = "🗝 Purchase Unlocked!"
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		let showGenres = segue.identifier == "COMBINE_GENRES"
		let destination = segue.destination as! CombineTableViewController
		destination.show(genres: showGenres)
	}

}

extension SettingsTableViewController {

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let cell = self.tableView(tableView, cellForRowAt: indexPath)
		return cell.isHidden ? 0 : super.tableView(tableView, heightForRowAt: indexPath)
	}

	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
//		guard let identifier = tableView.cellForRow(at: indexPath)?.reuseIdentifier else {
//			return nil
//		}
		return indexPath
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let identifier = tableView.cellForRow(at: indexPath)?.reuseIdentifier else {
			return
		}
		switch identifier {
		case "SETTINGS_COMBINE":
			break
		case "SETTINGS_RATE":
			let appId = "1415282075"
			let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appId)?action=write-review")!
			UIApplication.shared.open(url, options: [:])
		default:
			print("ERR", "Unknown row action", indexPath)
		}
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return section == 1 ? "v\(Bundle.main.version) by Kyle Coburn" : super.tableView(tableView, titleForFooterInSection: section)
	}

}
