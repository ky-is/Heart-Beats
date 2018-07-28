//
//  StepperViewController.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/27/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import UIKit

final class StepperViewController: UIViewController {

	@IBOutlet weak var stepper: GMStepper!

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if let maximum = songCollectionsViewController?.maximumSongs {
			stepper.maximumValue = Double(min(99, maximum))
		}
		stepper.value = Double(Zephyr.shared.userDefaults.minimum)
	}

	@IBAction func onMinimumSongs(_ sender: GMStepper) {
		Zephyr.shared.userDefaults.minimum = Int(sender.value)
	}

}
