//
//  AboutViewController.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 15/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {

	@IBOutlet weak var versionLabel: NSTextField!
	private let minimumVersionLabelWidth: CGFloat = 110

	override func viewDidLoad() {
        super.viewDidLoad()
		setVersionLabel()
    }

	@IBAction func menuBarDockWebsitePressed(_ sender: NSButton) {
		if let url = URL(string: "https://www.menubardock.com"),
			NSWorkspace.shared.open(url) {
		}
	}

	@IBAction func myWebsitePressed(_ sender: Any) {
		if let url = URL(string: "https://portosaurus.github.io/ethansk/"),
			NSWorkspace.shared.open(url) {
		}
	}
	@IBAction func etgGamesPressed(_ sender: NSButton) {
		if let url = URL(string: "https://www.etggames.com"),
			NSWorkspace.shared.open(url) {
		}
	}

	private func setVersionLabel() {
		guard let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return }
		versionLabel.stringValue = "Version \(version)"
		// The storyboard frame was sized for the old placeholder text
		// ("Version 69"). Semver labels such as "Version 4.7.0" are just wide
		// enough to clip the patch component, making the About window look like
		// it is still on the older two-part versioning scheme.
		let rightEdge = versionLabel.frame.maxX
		versionLabel.sizeToFit()
		let targetWidth = max(minimumVersionLabelWidth, ceil(versionLabel.frame.width))
		versionLabel.frame = NSRect(
			x: rightEdge - targetWidth,
			y: versionLabel.frame.origin.y,
			width: targetWidth,
			height: versionLabel.frame.height
		)
	}
}
