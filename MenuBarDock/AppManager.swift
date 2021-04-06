//
//  Model.swift
//  MenuBarDock
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
		func canShowRunningApp(app: NSRunningApplication) -> Bool{
			if app.bundleIdentifier == "com.apple.finder" {return !MenuBarDock.shared.userPrefs.hideFinder}
//			if MenuBarDock.shared.userPrefs.sortingMethod == .consistent {return true}
			if MenuBarDock.shared.userPrefs.hideActiveApp == false {return true}
			else {return app != NSWorkspace.shared.frontmostApplication}
			
			
		}
		return NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular && canShowRunningApp(app: $0)}// not sorted yet. tried many ways and couldn't get it ordered. it's fine, we can order them manually once we've kept track of which apps the user opened after this app has started. ideally it should be started on login
	}
	
	
	func effectiveAppName(_ app: NSRunningApplication) -> String{
		return app.localizedName ?? app.bundleIdentifier!
	}
	
	var runningAppsInOrder: [NSRunningApplication]{//will use appActivationsTracked to try and form the best order it can
		var result: [NSRunningApplication] = []
		let runningApps = self.runningApps //so we don't recalc every time func is invoked
		
		if MenuBarDock.shared.userPrefs.sortingMethod == .consistent {
			return runningApps.sorted{effectiveAppName($0) > effectiveAppName($1)}
		}
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
				self.appActivationsTracked.insert(app, at: 0)
				updated(notification)
			}
		}
	}
	
	func trackAppsBeingQuit(terminated: @escaping (_ notification: Notification) -> Void){
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			print("app quit")
			terminated(notification) //handle the updating in the calling closure

		}
	}
	
	
	
	func openApp(withBundleId bundleId: String){
		let appToOpen = MenuBarDock.shared.appManager.runningApps.filter{$0.bundleIdentifier == bundleId}.first
		if (appToOpen?.bundleIdentifier) == "com.apple.finder"{ //finder is weird and doesn't open normally
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) //do this as well if it's hidden
			appToOpen?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) //this is the only way i can get working to show the finder app
		}else{
			//i don't think there is a way to differentiate two different app versions that have the same bundle id eg matlab
			//its better to activate instead of launch because if there are multiple versions of the same app it will fucc u
			let shouldLaunchInsteadOfActivate = MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[appToOpen?.bundleIdentifier ?? ""] ?? MenuBarDock.shared.userPrefs.launchInsteadOfActivate
			
			if shouldLaunchInsteadOfActivate{
				NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
				
			}else{
				appToOpen?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) //this is the only way i can get working to show the finder app
				
			}
			
		}
	}
}

