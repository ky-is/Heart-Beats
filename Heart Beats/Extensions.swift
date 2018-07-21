//
//  Extensions.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 19/7/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import Foundation

extension Collection {

	subscript (safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}

}

public extension String {

	func plural(_ amount: Int) -> String {
		return amount == 1 ? self : "\(self)s"
	}

}
