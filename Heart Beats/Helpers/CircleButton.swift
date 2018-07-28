//
//  CircleButton.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/27/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

@IBDesignable final class CircleButton: UIButton {

	let inset: CGFloat = 6
	let circleLayer = CALayer()

	private func setup() {
		circleLayer.backgroundColor = tintColor.cgColor
		circleLayer.opacity = 0.75
		layer.addSublayer(circleLayer)

//		titleLabel?.textColor = .white
//		tintColor = .white
	}

	override func prepareForInterfaceBuilder() {
		setup()
	}

	override func awakeFromNib() {
		setup()
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		let size = bounds.height - inset * 2
		circleLayer.frame = CGRect(x: inset, y: inset, width: size, height: size)
		circleLayer.cornerRadius = size / 2
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)

		CATransaction.begin()
		CATransaction.setAnimationDuration(0.2)
		circleLayer.opacity = 1
		CATransaction.commit()
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)

		CATransaction.begin()
		CATransaction.setAnimationDuration(0.2)
		circleLayer.opacity = 0.75
		CATransaction.commit()
	}

}
