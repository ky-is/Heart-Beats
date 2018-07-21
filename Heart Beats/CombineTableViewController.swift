//
//  CombineTableViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/21/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

final class CombineTableViewController: UITableViewController {

	var combined = Zephyr.shared.userDefaults.combined

	override func viewDidLoad() {
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.combined), options: [.new], context: nil)
	}

	override func viewWillAppear(_ animated: Bool) {
		navigationController?.setToolbarHidden(false, animated: animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		navigationController?.setToolbarHidden(true, animated: animated)
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		updateCombined()
	}

	private func updateCombined() {
		combined = Zephyr.shared.userDefaults.combined
		tableView.reloadData()
	}

}

extension CombineTableViewController {

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return combined.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "COMBINE", for: indexPath)
		let combining = combined[indexPath.item]
		cell.textLabel?.text = "\(combining.first!)  ←  \(combining.dropFirst().joined(separator: ", "))"
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return "Allows you to combine an artist with multiple names in your library into one playlist."
	}

	override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
		//TODO
	}

}
