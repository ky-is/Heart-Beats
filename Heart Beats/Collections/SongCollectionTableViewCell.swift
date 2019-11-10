import UIKit

final class SongCollectionTableViewCell: UITableViewCell {

	@IBOutlet weak var iconImageView: UIImageView!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var countLabel: UILabel!

	override func awakeFromNib() {
		iconImageView.layer.cornerRadius = CORNER_RADIUS
		iconImageView.clipsToBounds = true
	}

}
