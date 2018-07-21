//
//  SettingsTableViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/21/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

final class SettingsTableViewController: UITableViewController {

	@IBOutlet weak var rateCell: UITableViewCell!
	@IBOutlet weak var restoreCell: UITableViewCell!

	override func viewDidLoad() {
		if IAP.unlocked {
			restoreCell.isHidden = true
		}
	}

}

extension SettingsTableViewController {

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let cell = self.tableView(tableView, cellForRowAt: indexPath)
		return cell.isHidden ? 0 : super.tableView(tableView, heightForRowAt: indexPath)
	}

	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		return tableView.cellForRow(at: indexPath)?.reuseIdentifier != nil ? indexPath : nil
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
		case "SETTINGS_RESTORE":
			IAP.shared.restore() { success in
				self.tableView.performBatchUpdates({
					self.restoreCell.isHidden = true
				}, completion: nil)
			}
		default:
			print("ERR", "Unknown row action", indexPath)
		}
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return section == 1 ? "v\(Bundle.main.version) by Kyle Coburn" : super.tableView(tableView, titleForFooterInSection: section)
	}

}
