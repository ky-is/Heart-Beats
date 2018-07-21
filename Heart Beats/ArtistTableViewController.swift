//
//  ArtistTableViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

private let reuseIdentifier = "ARTIST"
private let cellHeight = 64 //TODO cell

final class ArtistTableViewController: UITableViewController {

	@IBOutlet weak var backgroundView: UIView!

	var artists = [(String, MPMediaItem, MPMediaItemCollection)]()

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		artistTableViewController = self
	}

	override func viewDidLoad() {
		tableView.backgroundView = backgroundView
		tableView.tableFooterView = UIView(frame: .zero)
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return artists.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ArtistTableViewCell
		let artist = artists[indexPath.item]
		cell.nameLabel.text = artist.0
		cell.countLabel.text = artist.2.count.description
		DispatchQueue.global(qos: .userInitiated).async {
			let image = artist.1.artwork?.image(at: CGSize(width: cellHeight, height: cellHeight))
			DispatchQueue.main.async {
				if cell.nameLabel.text == artist.0 {
					cell.iconImageView.image = image
				}
			}
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let player = MPMusicPlayerController.systemMusicPlayer
		player.setQueue(with: artists[indexPath.item].2)
		player.shuffleMode = MPMusicShuffleMode.songs
		player.prepareToPlay()
		UIApplication.shared.open(URL(string: "audio-player-event:")!, options: [:], completionHandler: nil)
	}

	func setArtists(_ artists: [(String, MPMediaItem, MPMediaItemCollection)]) {
		self.artists = artists
		navigationItem.title = "\(artists.count) \("Artist".plural(artists.count))"
		backgroundView.isHidden = artists.count > 0
		tableView.reloadData()
	}

}
