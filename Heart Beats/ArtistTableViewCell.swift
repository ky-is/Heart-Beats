//
//  ArtistTableViewCell.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

final class ArtistTableViewCell: UITableViewCell {
    
	@IBOutlet weak var iconImageView: UIImageView!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var countLabel: UILabel!
	
	override func awakeFromNib() {
		iconImageView.layer.cornerRadius = 4
		iconImageView.clipsToBounds = true
	}

}
