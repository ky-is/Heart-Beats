//
//  SongCollectionsViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

final class SongCollectionsViewController: UIViewController {

	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var tabBar: UITabBar!

	@IBOutlet weak var backgroundView: UIView!
	@IBOutlet weak var backgroundLabel: UILabel!
	@IBOutlet weak var backgroundActionButton: UIButton!

	@IBOutlet weak var stepperButton: CircleButton!
	@IBOutlet weak var settingsBarButton: UIBarButtonItem!

	var maximumSongs = 99

	private var artists = [SongCollection]()
	private var genres = [SongCollection]()

	private var displayCollections = [[SongCollection]]()
	private var cachedArtworkIcons = NSCache<NSString, UIImage>()

	private let placeholder = #imageLiteral(resourceName: "note")
	private var cachedSize: CGSize?

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		songCollectionsViewController = self

		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.favorited), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.favoritedGenres), options: [.new], context: nil)
		Zephyr.shared.userDefaults.addObserver(self, forKeyPath: #keyPath(UserDefaults.minimum), options: [.new], context: nil)
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		tabBar.invalidateIntrinsicContentSize()
	}

	deinit {
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.favorited))
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.favoritedGenres))
		Zephyr.shared.userDefaults.removeObserver(self, forKeyPath: #keyPath(UserDefaults.minimum))
	}

	override func viewDidLoad() {
		tableView.backgroundView = backgroundView
		tableView.tableFooterView = UIView(frame: .zero)

		let bottomInset = view.safeAreaInsets.bottom + tabBar.bounds.height
		tableView.contentInset.bottom = bottomInset
		tableView.scrollIndicatorInsets.bottom = bottomInset

//		tabBar.itemSpacing = 48
//		tabBar.itemWidth = 128
//		tabBar.itemPositioning = .centered
		tabBar.selectedItem = tabBar.items![Zephyr.shared.userDefaults.showGenres ? 1 : 0]

		if !switchCollections() {
			navigationItem.setRightBarButton(nil, animated: false)
		}
	}

	func setUnavailable(status: MPMediaLibraryAuthorizationStatus) {
		backgroundView.isHidden = false
		navigationItem.title = "Music Unavailable"
		backgroundActionButton.setTitle("Open Settings", for: .normal)

		let detail: String
		switch status {
		case .restricted:
			detail = "change your library restrictions"
		default:
			detail = "change your permissions"
		}
		backgroundLabel.text = "Heart Beats requires access to your music library in order to create playlists based on your favorite artists.\n\nPlease \(detail) in the Settings app and try again. Thank you!"
	}

	func setCollections(_ collections: [SongCollection], _ maxCount: Int, _ current: Int) {
		let hasData = !collections.isEmpty
		if Zephyr.shared.userDefaults.showGenres {
			genres = collections
		} else {
			artists = collections
		}
		navigationItem.setRightBarButton(hasData ? settingsBarButton : nil, animated: true)
		backgroundView.isHidden = hasData

		maximumSongs = maxCount

		stepperButton.isHidden = !hasData
		if hasData {
			if Zephyr.shared.userDefaults.minimum < 2 {
				Zephyr.shared.userDefaults.minimum = current
			}
			stepperButton.setTitle(Zephyr.shared.userDefaults.minimum.description, for: .normal)
		}

		updateCollections()
	}

	private func switchCollections() -> Bool {
		let showGenres = Zephyr.shared.userDefaults.showGenres
		let collections = showGenres ? genres : artists
		if !collections.isEmpty {
			updateCollections()
		} else if MPMediaLibrary.authorizationStatus() == .authorized, let cached = showGenres ? UserDefaults.standard.cachedGenres : UserDefaults.standard.cachedArtists {
			let songCollections = cached.map { SongCollection(name: $0[0] as! String, songs: nil, songCount: $0[1] as! Int, artwork: nil) }
			setCollections(songCollections, 99, Zephyr.shared.userDefaults.minimum)
		} else {
			return false
		}
		return true
	}

	private func updateCollections() {
		let showGenres = Zephyr.shared.userDefaults.showGenres
		let collectionLabel = showGenres ? "Genre" : "Artist"
		let collections = showGenres ? genres : artists
		navigationItem.title = "\(SCREENSHOT_MODE ? (showGenres ? 21 : 42) : collections.count) \(collectionLabel.plural(collections.count))"
		updateFavorites()
	}

	private func updateFavorites() {
		let favorites = Zephyr.shared.userDefaults.getFavorites()
		let collections = Zephyr.shared.userDefaults.showGenres ? genres : artists
		let favoriteCollections = collections.filter { favorites.contains($0.name) }
		if !favoriteCollections.isEmpty {
			displayCollections = [ favoriteCollections, collections.filter { !favorites.contains($0.name) } ]
		} else {
			displayCollections = [ collections ]
		}
		tableView?.reloadData()
	}

	private func showFavorites() -> Bool {
		return displayCollections.count > 1
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == #keyPath(UserDefaults.minimum) {
			stepperButton?.setTitle(Zephyr.shared.userDefaults.minimum.description, for: .normal)
		} else {
			updateFavorites()
		}
	}

	private func songCollectionAt(indexPath: IndexPath) -> SongCollection {
		return displayCollections[indexPath.section][indexPath.item]
	}

	private func openMusicApp(completionHandler: ((Bool) -> ())? = nil) {
		let url = URL(string: "audio-player-event:")!
		if UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url, completionHandler: completionHandler)
		} else {
			alert("Unable to open Music.app", message: "Please manually rate some songs in your iOS system music library and try again. Thank you!", cancel: "OK")
		}
	}

	func play(songCollection: SongCollection) {
		let artistName = songCollection.name
		let played = Zephyr.shared.userDefaults.getPlayed()
		if !played.contains(artistName) {
			var favorites = Zephyr.shared.userDefaults.getFavorites()
			if favorites.count < 3 {
				favorites.append(artistName)
				if Zephyr.shared.userDefaults.showGenres {
					Zephyr.shared.userDefaults.favoritedGenres = favorites
				} else {
					Zephyr.shared.userDefaults.favorited = favorites
				}
			} else if !IAP.unlocked {
				return purchaseAlert(message: "In order to play more artists, you'll need to purchase the full application.")
			}
			if Zephyr.shared.userDefaults.showGenres {
				Zephyr.shared.userDefaults.playedGenres.append(artistName)
			} else {
				Zephyr.shared.userDefaults.played.append(artistName)
			}
		}

		let buildAlert = UIAlertController(title: "Queueing \(artistName) playlist...\n🎶🎵🎶🎵🎶", message: "", preferredStyle: .alert)
		present(buildAlert, animated: true)

		DispatchQueue.global(qos: .userInteractive).async {
			let player = MPMusicPlayerController.systemMusicPlayer
			player.setQueue(with: songCollection.songs!)
			player.shuffleMode = MPMusicShuffleMode.songs
			player.prepareToPlay()

			DispatchQueue.main.async {
				self.openMusicApp() { success in
					buildAlert.dismiss(animated: true)
				}
			}
		}
	}

	func available(songCollection name: String, image: UIImage) {
		for cell in tableView.visibleCells {
			guard let cell = cell as? SongCollectionTableViewCell else {
				continue
			}
			if cell.nameLabel.text == name {
				cell.iconImageView.image = image
				return
			}
		}
	}

	func purchaseAlert(message: String) {
		let purchaseAction = UIAlertAction(title: "Unlock", style: .cancel) { action in
			IAP.shared.purchase(from: self)
		}
		alert("Unlock required", message: "\(message) Or, keep playing your existing favorites free, forever!", cancel: "Not now", customAction: purchaseAction)
	}

}

extension SongCollectionsViewController: UIPopoverPresentationControllerDelegate {

	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}

	func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
		return .none
	}

}

//MARK: Actions

extension SongCollectionsViewController {

	@IBAction func onMinimumButton(_ sender: UIButton) {
		let popController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MINIMUM")
		popController.modalPresentationStyle = UIModalPresentationStyle.popover
		popController.popoverPresentationController?.permittedArrowDirections = .up
		popController.popoverPresentationController?.delegate = self
		popController.popoverPresentationController?.sourceView = sender
		popController.popoverPresentationController?.sourceRect = sender.bounds
		popController.preferredContentSize = CGSize(width: 300, height: 128)
		present(popController, animated: true, completion: nil)
	}

	@IBAction func onBackgroundButton(_ sender: UIButton) {
		if sender.title(for: .normal) == "Open Music" {
			openMusicApp()
		} else {
			let url = URL(string: UIApplicationOpenSettingsURLString)!
			UIApplication.shared.open(url)
		}
	}

}

//MARK: TabBar

extension SongCollectionsViewController: UITabBarDelegate {

	func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
		Zephyr.shared.userDefaults.showGenres = item.tag == 1

		_ = switchCollections()
	}

}

//MARK: TableView

extension SongCollectionsViewController: UITableViewDelegate {

	private func titleFor(header section: Int) -> String {
		return section == 0 ? "Favorites" : "Uncategorized"
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return showFavorites() ? titleFor(header: section) : nil
	}

	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return showFavorites() ? 38 : 0
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HEADER") as! HeaderTableViewCell
		cell.nameLabel.text = titleFor(header: section)
		return cell
	}

	func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		let songCollection = songCollectionAt(indexPath: indexPath)
		return songCollection.songs != nil ? indexPath : nil
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let songCollection = songCollectionAt(indexPath: indexPath)
		play(songCollection: songCollection)
	}

	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let addToFavorites = !showFavorites() || indexPath.section == 1
		let title = addToFavorites ? "⭐️" : "☆"
		let favoriteAction = UIContextualAction(style: addToFavorites ? .normal : .destructive, title: title) { (action, view, handler) in
			if !IAP.unlocked {
				self.purchaseAlert(message: "In order to manage your favorites, you'll need to purchase the full application.")
			} else {
				let songCollection = self.songCollectionAt(indexPath: indexPath)
				let songCollectionName = songCollection.name
				var favorites = Zephyr.shared.userDefaults.getFavorites()
				if favorites.contains(songCollectionName) {
					favorites = favorites.filter { $0 != songCollectionName}
				} else {
					favorites.append(songCollectionName)
				}
				if Zephyr.shared.userDefaults.showGenres {
					Zephyr.shared.userDefaults.favoritedGenres = favorites
				} else {
					Zephyr.shared.userDefaults.favorited = favorites
				}
			}
			handler(true)
		}
		if addToFavorites {
			favoriteAction.backgroundColor = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
		}
		return UISwipeActionsConfiguration(actions: [ favoriteAction ])
	}

}

extension SongCollectionsViewController: UITableViewDataSource {

	func numberOfSections(in tableView: UITableView) -> Int {
		return displayCollections.count
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return displayCollections[section].count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ARTIST", for: indexPath) as! SongCollectionTableViewCell
		let songCollection = songCollectionAt(indexPath: indexPath)
		let name = songCollection.name
		cell.nameLabel.text = name
		cell.countLabel.text = songCollection.songCount.description
		if let cachedIcon = cachedArtworkIcons.object(forKey: name as NSString) {
			cell.iconImageView.image = cachedIcon
		} else if let artwork = songCollection.artwork {
			if cachedSize == nil {
				cachedSize = cell.iconImageView.bounds.size
			}
			DispatchQueue.global(qos: .userInitiated).async {
				let image = artwork.image(at: self.cachedSize!) ?? artwork.image(at: artwork.bounds.size)
				self.cachedArtworkIcons.setObject(image ?? self.placeholder, forKey: name as NSString)
				if let image = image {
					DispatchQueue.main.async {
						if cell.nameLabel.text == name {
							self.available(songCollection: name, image: image)
						}
					}
				}
			}
			if SCREENSHOT_MODE && !(cell.subviews.last is UIVisualEffectView) {
				let blurEffect = UIBlurEffect(style: .regular)
				let blurredEffectView = UIVisualEffectView(effect: blurEffect)
				blurredEffectView.frame = cell.iconImageView.frame
				blurredEffectView.frame.origin.x = UIDevice.current.userInterfaceIdiom == .pad ? 15 : 20
				blurredEffectView.layer.cornerRadius = 4
				blurredEffectView.clipsToBounds = true

				let vibrantEffect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .prominent))
				let vibrantEffectView = UIVisualEffectView(effect: vibrantEffect)
				vibrantEffectView.frame = blurredEffectView.bounds
				let imageView = UIImageView(frame: blurredEffectView.bounds)
				imageView.image = #imageLiteral(resourceName: "note-a")
				vibrantEffectView.contentView.addSubview(imageView)
				blurredEffectView.contentView.addSubview(vibrantEffectView)
				cell.addSubview(blurredEffectView)
			}
		} else {
			cell.iconImageView.image = placeholder
		}
		return cell
	}

}

//MARK: Peek

extension SongCollectionsViewController {

	override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
		return identifier != "SONGS_PEEK"
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "SONGS_PREVIEW" {
			let destinationController = segue.destination as! UINavigationController
			if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell), let songController = destinationController.topViewController as? SongTableViewController {
				let songCollection = songCollectionAt(indexPath: indexPath)
				songController.setArtist(songCollection)
			}
		}
	}

}
