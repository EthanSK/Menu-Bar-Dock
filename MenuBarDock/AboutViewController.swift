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
	}
}
