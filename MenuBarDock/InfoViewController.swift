//
//  InfoViewController.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 16/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class InfoViewController: NSViewController {

	@IBOutlet weak var label: NSTextField!

	let info = [
		"Hold command ⌘ while dragging an icon to move its position in the menu bar.",
		"If clicking on an app in the menu bar doesn't have the desired effect, try changing the app opening method for that app by right clicking it in the menu bar dock",
		"If \(Constants.App.name) is getting slow, just restart it, and it will clear out and reset all the unused status items. This should happen very rarely if at all",
		"If you don't want to use the \(Constants.App.runningAppsSectionTitle) feature, just set the max number of running appps to 0. If you don't want to use the \(Constants.App.regularAppsSectionTitle) feature, just remove all the apps from the list.",
		"You can add multiple versions of the same app to the \(Constants.App.regularAppsSectionTitle) list as long as they have a different path on your system."
	]

	override func viewDidLoad() {
		super.viewDidLoad()
		label.stringValue = info.reduce("", { (res, next) -> String in
			res + "• " + next + "\n\n"

		})
	}

}
