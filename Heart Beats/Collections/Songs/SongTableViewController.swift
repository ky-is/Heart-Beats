import UIKit

import MediaPlayer

final class SongTableViewController: UITableViewController {

	public var songCollection: SongCollection!

	private var songs = [MPMediaItem]()

	private let durationFormatter = DateComponentsFormatter()

	override func awakeFromNib() {
		durationFormatter.allowedUnits = [.minute, .second]
		durationFormatter.unitsStyle = .positional
		durationFormatter.zeroFormattingBehavior = .pad
	}

	public func setArtist(_ songCollection: SongCollection) {
		self.songCollection = songCollection
		songs = songCollection.songs!.items
		navigationItem.title = songCollection.name
	}

	@IBAction func onDone(_ sender: UIBarButtonItem) {
		dismiss(animated: true, completion: nil)
	}

	@IBAction func onPlay(_ sender: UIBarButtonItem) {
		play()
		dismiss(animated: true, completion: nil)
	}

	func play() {
		songCollectionsViewController?.play(songCollection: self.songCollection)
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
		let preview = UIPreviewAction(title: "Play", style: .default) { (action, controller) in
			self.play()
		}
		return [ preview ]
	}

}
