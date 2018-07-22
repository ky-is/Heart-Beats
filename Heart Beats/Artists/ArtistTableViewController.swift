//
//  ArtistTableViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

final class ArtistTableViewController: UITableViewController {

	@IBOutlet weak var backgroundView: UIView!
	@IBOutlet weak var stepperView: GMStepper!
	@IBOutlet weak var toolbarItem: UIBarButtonItem!

	var artists = [[Any]]()
	var displayArtists = [[[Any]]]()

	private let placeholder = UIImage(imageLiteralResourceName: "note")

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		artistTableViewController = self

		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.favorited), options: [.new], context: nil)
	}

	deinit {
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.favorited))
	}

	override func viewDidLoad() {
		tableView.backgroundView = backgroundView
		tableView.tableFooterView = UIView(frame: .zero)

		toolbarItem.customView = stepperView

		if let cached = UserDefaults.standard.cachedArtists {
			setArtists(cached, 99, Zephyr.shared.userDefaults.minimum)
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		navigationController?.setToolbarHidden(false, animated: animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		navigationController?.setToolbarHidden(true, animated: animated)
	}

	func setArtists(_ artists: [[Any]], _ maxCount: Int, _ current: Int) {
		self.artists = artists
		navigationItem.title = "\(artists.count) \("Artist".plural(artists.count))"
		backgroundView.isHidden = !artists.isEmpty
		if stepperView.value <= 2 {
			stepperView.value = Double(current)
		}
		stepperView.maximumValue = Double(maxCount)

		updateFavorites()
	}

	private func updateFavorites() {
		let favorites = Zephyr.shared.userDefaults.favorited
		let favoriteArtists = artists.filter { favorites.contains($0.first as! String) }
		if !favoriteArtists.isEmpty {
			displayArtists = [ favoriteArtists, artists.filter { !favorites.contains($0.first as! String) } ]
		} else {
			displayArtists = [ artists ]
		}
		tableView.reloadData()
	}

	private func showFavorites() -> Bool {
		return displayArtists.count > 1
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		updateFavorites()
	}

	private func artistAt(indexPath: IndexPath) -> [Any] {
		return displayArtists[indexPath.section][indexPath.item]
	}

	func play(artist: [Any]) {
		let artistName = artist.first as! String
		var played = Zephyr.shared.userDefaults.played
		if !played.contains(artistName) {
			var favorited = Zephyr.shared.userDefaults.favorited
			if favorited.count < 3 {
				favorited.append(artistName)
				Zephyr.shared.userDefaults.favorited = favorited
			} else if !IAP.unlocked {
				return purchaseAlert(message: "In order to play more artists, you'll need to purchase the full application.")
			}
			played.append(artistName)
			Zephyr.shared.userDefaults.played = played
		}

		let buildAlert = UIAlertController(title: "Queueing \(artistName) playlist...\n🎶🎵🎶🎵🎶", message: "", preferredStyle: .alert)
		present(buildAlert, animated: true)

		DispatchQueue.global(qos: .userInteractive).async {
			let player = MPMusicPlayerController.systemMusicPlayer
			player.setQueue(with: artist[2] as! MPMediaItemCollection)
			player.shuffleMode = MPMusicShuffleMode.songs
			player.prepareToPlay()

			DispatchQueue.main.async {
				UIApplication.shared.open(URL(string: "audio-player-event:")!, options: [:]) { success in
					buildAlert.dismiss(animated: true)
				}
			}
		}
	}

	@IBAction func onMinimumSongs(_ sender: GMStepper) {
		Zephyr.shared.userDefaults.minimum = Int(sender.value)
	}

}

//MARK: TableView

extension ArtistTableViewController {

	override func numberOfSections(in tableView: UITableView) -> Int {
		return displayArtists.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return displayArtists[section].count
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return showFavorites() ? UITableViewAutomaticDimension : 0
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HEADER") as! HeaderTableViewCell
		cell.nameLabel.text = section == 0 ? "Favorites" : "Others"
		return cell
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ARTIST", for: indexPath) as! ArtistTableViewCell
		let artist = artistAt(indexPath: indexPath)
		cell.nameLabel.text = artist.first as? String
		cell.iconImageView.image = artist[1] as? UIImage ?? placeholder
		if let count = artist[2] as? Int {
			cell.countLabel.text = count.description
		} else if let collection = artist[2] as? MPMediaItemCollection {
			cell.countLabel.text = collection.count.description
		}
		return cell
	}

	func purchaseAlert(message: String) {
		let purchaseAction = UIAlertAction(title: "Unlock", style: .cancel) { action in
			IAP.shared.purchase(from: self)
		}
		alert("Unlock required", message: "\(message) Or, keep playing your existing favorites free, forever!", cancel: "Not now", customAction: purchaseAction)
	}

	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		let artist = artistAt(indexPath: indexPath)
		return artist[2] is MPMediaItemCollection ? indexPath : nil
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let artist = artistAt(indexPath: indexPath)
		play(artist: artist)
	}

}

//MARK: Swipe

extension ArtistTableViewController {

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let addToFavorites = !showFavorites() || indexPath.section == 1
		let title = addToFavorites ? "⭐️" : "☆"
		let favoriteAction = UIContextualAction(style: addToFavorites ? .normal : .destructive, title: title) { (action, view, handler) in
			if !IAP.unlocked {
				self.purchaseAlert(message: "In order to manage your favorites, you'll need to purchase the full application.")
			} else {
				let artist = self.artistAt(indexPath: indexPath)
				let artistName = artist.first as! String
				var favorites = Zephyr.shared.userDefaults.favorited
				if favorites.contains(artistName) {
					favorites = favorites.filter { $0 != artistName}
				} else {
					favorites.append(artistName)
				}
				Zephyr.shared.userDefaults.favorited = favorites
			}
			handler(true)
		}
		if addToFavorites {
			favoriteAction.backgroundColor = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
		}
		return UISwipeActionsConfiguration(actions: [ favoriteAction ])
	}

}

//MARK: Peek

extension ArtistTableViewController {

	override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
		return identifier != "SONGS_PEEK"
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "SONGS_PREVIEW" {
			let destinationController = segue.destination as! UINavigationController
			if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell), let songController = destinationController.topViewController as? SongTableViewController {
				let artist = artistAt(indexPath: indexPath)
				songController.setArtist(artist)
			}
		}
	}

}
