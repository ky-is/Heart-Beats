//
//  ArtistTableViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

private let cellHeight = 64 //TODO cell
private let artworkSize = CGSize(width: cellHeight, height: cellHeight)

final class ArtistTableViewController: UITableViewController {

	@IBOutlet weak var backgroundView: UIView!

	var artists = [(String, MPMediaItem, MPMediaItemCollection)]()
	var displayArtists = [[(String, MPMediaItem, MPMediaItemCollection)]]()

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		artistTableViewController = self

		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.favorited), options: [.new], context: nil)
	}

	override func viewDidLoad() {
		tableView.backgroundView = backgroundView
		tableView.tableFooterView = UIView(frame: .zero)
	}

	func setArtists(_ artists: [(String, MPMediaItem, MPMediaItemCollection)]) {
		self.artists = artists
		navigationItem.title = "\(artists.count) \("Artist".plural(artists.count))"
		backgroundView.isHidden = artists.count > 0

		updateFavorites()
	}

	private func updateFavorites() {
		let favorites = Zephyr.shared.userDefaults.favorited
		let favoriteArtists = artists.filter { favorites.contains($0.0) }
		if favoriteArtists.count > 0 {
			displayArtists = [ favoriteArtists, artists.filter { !favorites.contains($0.0) } ]
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
		return showFavorites() ? UITableView.automaticDimension : 0
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HEADER") as! HeaderTableViewCell
		cell.nameLabel.text = section == 0 ? "Favorites" : "Others"
		return cell
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ARTIST", for: indexPath) as! ArtistTableViewCell
		let artist = displayArtists[indexPath.section][indexPath.item]
		let artistName = artist.0
		cell.nameLabel.text = artistName
		cell.countLabel.text = artist.2.count.description
		if let artwork = artist.1.artwork {
			DispatchQueue.global(qos: .userInitiated).async {
				let image = artwork.image(at: artworkSize) ?? artwork.image(at: artwork.bounds.size)
				DispatchQueue.main.async {
					if cell.nameLabel.text == artistName {
						cell.iconImageView.image = image
					}
				}
			}
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let artist = displayArtists[indexPath.section][indexPath.item]
		let artistName = artist.0
		var played = Zephyr.shared.userDefaults.played
		if !played.contains(artistName) {
			var favorited = Zephyr.shared.userDefaults.favorited
			if favorited.count < 3 {
				favorited.append(artistName)
				Zephyr.shared.userDefaults.favorited = favorited
			} else if !IAP.unlocked {
				let purchaseAction = UIAlertAction(title: "Unlock", style: .cancel) { action in
					IAP.shared.purchase(from: self)
				}
				alert("Unlock required", message: "In order to play more artists, you'll need to purchase the full application. Or, keep using your existing favorites free, forever!", cancel: "Not now", customAction: purchaseAction)
				return
			}
			played.append(artistName)
			Zephyr.shared.userDefaults.played = played
		}

		let player = MPMusicPlayerController.systemMusicPlayer
		player.setQueue(with: artist.2)
		player.shuffleMode = MPMusicShuffleMode.songs
		player.prepareToPlay()
		UIApplication.shared.open(URL(string: "audio-player-event:")!, options: [:], completionHandler: nil)
	}

}
