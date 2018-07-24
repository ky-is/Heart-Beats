//
//  SongTableViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/21/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

import MediaPlayer

final class SongTableViewController: UITableViewController {

	public var artist: Artist!

	private var songs = [MPMediaItem]()

	private let durationFormatter = DateComponentsFormatter()

	override func awakeFromNib() {
		durationFormatter.allowedUnits = [.minute, .second]
		durationFormatter.unitsStyle = .positional
		durationFormatter.zeroFormattingBehavior = .pad
	}

	public func setArtist(_ artist: Artist) {
		self.artist = artist
		songs = artist.songs!.items
		navigationItem.title = artist.name
	}

	@IBAction func onDone(_ sender: UIBarButtonItem) {
		dismiss(animated: true, completion: nil)
	}

	@IBAction func onPlay(_ sender: UIBarButtonItem) {
		play()
		dismiss(animated: true, completion: nil)
	}

	func play() {
		artistTableViewController?.play(artist: self.artist)
	}

}

extension SongTableViewController {

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return songs.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SONG", for: indexPath) as! SongTableViewCell
		let song = songs[indexPath.item]
		cell.nameLabel.text = song.title

		if let formattedString = durationFormatter.string(from: song.playbackDuration) {
			cell.timeLabel.text = formattedString
		}
		return cell
	}

}

extension SongTableViewController {

	override var previewActionItems: [UIPreviewActionItem] {
		let preview = UIPreviewAction(title: "Play", style: UIPreviewActionStyle.default) { (action, controller) in
			self.play()
		}
		return [ preview ]
	}

}
