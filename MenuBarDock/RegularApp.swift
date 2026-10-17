//
//  RegularApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 13/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class RegularApp {
	public let url: URL
	public let bundle: Bundle?
	public let isFolder: Bool
	public var icon: NSImage
	public var name: String
	public var runningApp: NSRunningApplication? // once we open a regular app, it will be running, and so we want to show options for running apps in the dropdown menu such as 'quit'

	var id: String {
		url.absoluteString
	}

	init(
		bundle: Bundle,
		icon: NSImage,
		name: String
	) {
		self.bundle = bundle
		self.url = bundle.bundleURL
		self.isFolder = false
		self.icon = icon
		self.name = name
	}

    init(folderURL: URL) {
        url = folderURL
        bundle = nil
        isFolder = true
        icon = NSWorkspace.shared.icon(forFile: folderURL.path)
        name = FileManager.default.displayName(atPath: folderURL.path)
    }

    /// App bundles are directories too. Keep their launch behavior distinct from folders.
    static func isPinnableFolder(_ url: URL) -> Bool {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else { return false }
        return values.isDirectory == true && values.isPackage != true && url.pathExtension.lowercased() != "app"
    }

}
