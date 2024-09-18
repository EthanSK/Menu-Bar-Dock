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
		"Hover over a setting in the preferences window with your cursor to see a tooltip explaining what that setting does.",
		"Hold command ⌘ while dragging an icon to move its position in the menu bar.",
		"If clicking on an app in the menu bar doesn't have the desired effect, try changing the app opening method for that app by right clicking it in the menu bar dock",
		"If \(Constants.App.name) is getting slow, just restart it, and it will clear out and reset all the unused status items. This should happen very rarely if at all",
		"If you don't want to use the \(Constants.App.runningAppsSectionTitle) feature, just set the max number of running apps to 0. If you don't want to use the \(Constants.App.regularAppsSectionTitle) feature, just remove all the apps from the list.",
		"You can add multiple versions of the same app to the \(Constants.App.regularAppsSectionTitle) list as long as they have a different path on your system.",
		"You may notice the ordering of apps will be incorrect when you first open \(Constants.App.name). This is because it tracks what apps you open and close after opening \(Constants.App.name), so it will take a little bit of time to settle. This issue can be avoided if you simple keep 'Launch at Login' on."
	]

	override func viewDidLoad() {
		super.viewDidLoad()
		label.stringValue = info.enumerated().reduce("", { (res, next) -> String in
			res + "• " + next.element + (next.offset == info.count - 1 ? "" : "\n\n")
		})
	}

}
