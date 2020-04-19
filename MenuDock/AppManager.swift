//
//  Model.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class AppManager: NSObject {
	
	
	override init(){
		appActivationsTracked = []
		super.init()
	} 
	
	private var appActivationsTracked: [NSRunningApplication]{
		didSet{
			appActivationsTracked = appActivationsTracked.unique
		}
	}
	
	private var runningApps: [NSRunningApplication]{
		return NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular && $0 != NSWorkspace.shared.frontmostApplication}// not sorted yet. tried many ways and couldn't get it ordered. it's fine, we can order them manually once we've kept track of which apps the user opened after this app has started. ideally it should be started on login
	}
	
	var runningAppsInOrder: [NSRunningApplication]{//will use appActivationsTracked to try and form the best order it can
		var result: [NSRunningApplication] = []
		let runningApps = self.runningApps //so we don't recalc every time func is invoked
		for appActivated in appActivationsTracked{ //first add the apps we have ordering info of AND that we know are running
			if runningApps.contains(appActivated){
				result.append(appActivated)
			}
		}
		for runningApp in runningApps{ //then add the remaining apps we had no ordering info for
			if !result.contains(runningApp){
				result.append(runningApp)
			}
		}
		return result
	}
	
	
	func trackAppsBeingActivated(updated: @escaping (_ notification: Notification) -> Void){//to allow us to form some sort of order in the menu bar
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, NSWorkspace.shared.frontmostApplication == app{ //make sure it wasn't triggered by some background process
//				print("app activated: ", app.localizedName)
				self.appActivationsTracked.insert(app, at: 0)
				updated(notification)
			}
		}
	}
	
	func trackAppsBeingQuit(terminated: @escaping (_ notification: Notification) -> Void){
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			print("app quit")
			terminated(notification) //handle the updating in the calling closure
			//			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
			//				print("app quit: ", app.localizedName)
			//				terminated(notification)
			//			}
		}
	}
	
	
	
	func openApp(withBundleId bundleId: String){
		let firstApp = MenuDock.shared.appManager.runningApps.filter{$0.bundleIdentifier == bundleId}.first
		if (firstApp?.bundleIdentifier) == "com.apple.finder"{ //finder is weird and doesn't open normally
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) //do this as well if it's hidden
			firstApp?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) //this is the only way i can get working to show the finder app
		}else{
			//i don't think there is a way to differentiate two different app versions that have the same bundle id eg matlab
			//its better to activate instead of launch because if there are multiple versions of the same app it will fucc up
			if MenuDock.shared.userPrefs.launchInsteadOfActivate{
				NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
				
			}else{
				firstApp?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) //this is the only way i can get working to show the finder app
				
			}
			
		}
		
		if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleId{
			firstApp?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) //if the have pressed the same icon twice, they must really wanna go to that app so force it. it doesn't work for finder tho rip
		}
	}
}

