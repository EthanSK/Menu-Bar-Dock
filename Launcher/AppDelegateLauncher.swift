//
//  AppDelegate.swift
//  Launcher
//
//  Created by Ethan Sarif-Kattan on 04/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa


extension Notification.Name {
	static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegateLauncher: NSObject {
	
	@objc func terminate() {
		NSApp.terminate(nil) //off for testing
	}
}




extension AppDelegateLauncher: NSApplicationDelegate {

	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let mainAppIdentifier = "com.etggames.MenuDock"
		let runningApps = NSWorkspace.shared.runningApplications
		let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty
		
		if !isRunning {
			DistributedNotificationCenter.default().addObserver(self,
																selector: #selector(self.terminate),
																name: .killLauncher,
																object: mainAppIdentifier)
			
			let path = Bundle.main.bundlePath as NSString
			var components = path.pathComponents
			components.removeLast()
			components.removeLast()
			components.removeLast()
			components.removeLast() //launche the .app, not the binary

//			components.append("MacOS")
//			components.append("Menu Bar Dock") //main app name
			
			let newPath = NSString.path(withComponents: components)
			
			NSWorkspace.shared.launchApplication(newPath)
		}
		else {
			self.terminate()
		}
	}
}
