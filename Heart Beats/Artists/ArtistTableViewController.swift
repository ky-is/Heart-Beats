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
	@IBOutlet weak var backgroundLabel: UILabel!
	@IBOutlet weak var backgroundSettingsButton: UIButton!

	@IBOutlet weak var stepperView: GMStepper!
	@IBOutlet weak var toolbarItem: UIBarButtonItem!

	private var artists = [Artist]()
	private var displayArtists = [[Artist]]()
	private var cachedArtworkIcons = NSCache<NSString, UIImage>()

	private let placeholder = UIImage(imageLiteralResourceName: "note")
	private var cachedSize: CGSize?

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		artistTableViewController = self

		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.favorited), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.minimum), options: [.new], context: nil)
	}

	deinit {
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.favorited))
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.minimum))
	}

	override func viewDidLoad() {
		tableView.backgroundView = backgroundView
		tableView.tableFooterView = UIView(frame: .zero)

		toolbarItem.customView = stepperView

		if MPMediaLibrary.authorizationStatus() == .authorized, let cached = UserDefaults.standard.cachedArtists {
			let artists = cached.map { Artist(name: $0[0] as! String, songs: nil, songCount: $0[1] as! Int, artwork: nil) }
			setArtists(artists, 99, Zephyr.shared.userDefaults.minimum)
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		navigationController?.setToolbarHidden(false, animated: animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		navigationController?.setToolbarHidden(true, animated: animated)
	}

	func setUnavailable(status: MPMediaLibraryAuthorizationStatus) {
		backgroundView.isHidden = false
		navigationItem.title = "Music Unavailable"
		backgroundSettingsButton.isHidden = false

		let detail: String
		switch status {
		case .restricted:
			detail = "change your library restrictions"
		default:
			detail = "change your permissions"
		}
		backgroundLabel.text = "Heart Beats requires access to your music library in order to create playlists based on your favorite artists.\n\nPlease \(detail) in the Settings app and try again. Thank you!"
	}

	func setArtists(_ artists: [Artist], _ maxCount: Int, _ current: Int) {
		self.artists = artists
		navigationItem.title = "\(artists.count) \("Artist".plural(artists.count))" //SAMPLE
		backgroundView.isHidden = !artists.isEmpty
		if stepperView.value <= 2 {
			stepperView.value = Double(current)
		}
		stepperView.maximumValue = Double(maxCount)

		updateFavorites()
	}

	private func updateFavorites() {
		let favorites = Zephyr.shared.userDefaults.favorited
		let favoriteArtists = artists.filter { favorites.contains($0.name) }
		if !favoriteArtists.isEmpty {
			displayArtists = [ favoriteArtists, artists.filter { !favorites.contains($0.name) } ]
		} else {
			displayArtists = [ artists ]
		}
		tableView.reloadData()
	}

	private func showFavorites() -> Bool {
		return displayArtists.count > 1
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == #keyPath(UserDefaults.minimum) {
			stepperView.value = Double(Zephyr.shared.userDefaults.minimum)
		} else {
			updateFavorites()
		}
	}

	private func artistAt(indexPath: IndexPath) -> Artist {
		return displayArtists[indexPath.section][indexPath.item]
	}

	func play(artist: Artist) {
		let artistName = artist.name
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
			player.setQueue(with: artist.songs!)
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

	@IBAction func onSettingsButton(_ sender: UIButton) {
		let url = URL(string: UIApplicationOpenSettingsURLString)!
		UIApplication.shared.open(url)
	}

	func available(artist name: String, image: UIImage) {
		for cell in tableView.visibleCells {
			guard let cell = cell as? ArtistTableViewCell else {
				continue
			}
			if cell.nameLabel.text == name {
				cell.iconImageView.image = image
				return
			}
		}
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
		cell.nameLabel.text = section == 0 ? "Favorites" : "Uncategorized"
		return cell
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ARTIST", for: indexPath) as! ArtistTableViewCell
		let artist = artistAt(indexPath: indexPath)
		let name = artist.name
		cell.nameLabel.text = name
		cell.countLabel.text = artist.songCount.description
		if let cachedIcon = cachedArtworkIcons.object(forKey: name as NSString) {
			cell.iconImageView.image = cachedIcon
		} else if let artwork = artist.artwork {
			if cachedSize == nil {
				cachedSize = cell.iconImageView.bounds.size
			}
			DispatchQueue.global(qos: .userInitiated).async {
				let image = artwork.image(at: self.cachedSize!) ?? artwork.image(at: artwork.bounds.size)
				self.cachedArtworkIcons.setObject(image ?? self.placeholder, forKey: name as NSString)
				if let image = image {
					DispatchQueue.main.async {
						if cell.nameLabel.text == name {
							artistTableViewController?.available(artist: name, image: image)
						}
					}
				}
			}
		} else {
			cell.iconImageView.image = placeholder
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
		return artist.songs != nil ? indexPath : nil
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
				let artistName = artist.name
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
