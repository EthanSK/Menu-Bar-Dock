//
//  UserPrefs.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum UserPrefsDefaultValues{
	static let numberOfStatusItems = 7 //make it go up really high so user has freedom if the have a very large long screen
	static let widthOfStatusItem = CGFloat(30)
	static let sortingMethod: SortingMethod = .mostRecentOnRight
	static let iconSize: CGFloat = 21
	static let launchAtLogin = true //appaz mac app store doesn't allow default true
	static let launchInsteadOfActivate = true //should activate app by default
	static let launchInsteadOfActivateIndivApps: [String: Bool] = ["com.apple.finder": true]
	static let hideActiveApp = true
	static let hideFinder = false
}

class UserPrefs: NSObject { //TODO: have options to reset all these to default
	var numberOfStatusItems = UserPrefsDefaultValues.numberOfStatusItems //make it go up really high so user has freedom if the have a very large long screen
	var widthOfStatusItem = UserPrefsDefaultValues.widthOfStatusItem
	var sortingMethod: SortingMethod = UserPrefsDefaultValues.sortingMethod
	var iconSize: CGFloat = UserPrefsDefaultValues.iconSize
	var launchAtLogin = UserPrefsDefaultValues.launchAtLogin
	var launchInsteadOfActivate = UserPrefsDefaultValues.launchInsteadOfActivate
	var launchInsteadOfActivateIndivApps = UserPrefsDefaultValues.launchInsteadOfActivateIndivApps
	var hideActiveApp = UserPrefsDefaultValues.hideActiveApp
	var hideFinder = UserPrefsDefaultValues.hideFinder
	
	override init(){
		super.init()
		load()  
	}
	
	func resetToDefaults(){ //cba about this shitty code tbh not worth my time
		numberOfStatusItems =  UserPrefsDefaultValues.numberOfStatusItems //make it go up really high so user has freedom if the have a very large long screen
		widthOfStatusItem = UserPrefsDefaultValues.widthOfStatusItem
		sortingMethod = UserPrefsDefaultValues.sortingMethod
		iconSize = UserPrefsDefaultValues.iconSize
		launchInsteadOfActivate = UserPrefsDefaultValues.launchInsteadOfActivate
		hideActiveApp = UserPrefsDefaultValues.hideActiveApp
		hideFinder = UserPrefsDefaultValues.hideFinder
		
		save()
	}
	func resetIndivAppSettingsToDefaults(){
		launchInsteadOfActivateIndivApps = UserPrefsDefaultValues.launchInsteadOfActivateIndivApps
	}
	
	func save(){
		
		UserDefaults.standard.set(numberOfStatusItems, forKey: Constants.UserPrefs.numberOfStatusItems) 
		UserDefaults.standard.set(widthOfStatusItem, forKey: Constants.UserPrefs.widthOfStatusItem) 
		UserDefaults.standard.set(sortingMethod.rawValue, forKey: Constants.UserPrefs.sortingMethod) 
		UserDefaults.standard.set(iconSize, forKey: Constants.UserPrefs.iconSize)  
		UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserPrefs.launchAtLogin)
		UserDefaults.standard.set(launchInsteadOfActivate, forKey: Constants.UserPrefs.launchInsteadOfActivate)
		UserDefaults.standard.set(launchInsteadOfActivateIndivApps, forKey: Constants.UserPrefs.launchInsteadOfActivateIndivApps)
		UserDefaults.standard.set(hideActiveApp, forKey: Constants.UserPrefs.hideActiveApp)
		UserDefaults.standard.set(hideFinder, forKey: Constants.UserPrefs.hideFinder)

	}
	
	func load(){
		if let numberOfStatusItems = UserDefaults.standard.object(forKey: Constants.UserPrefs.numberOfStatusItems) as? Int{
			self.numberOfStatusItems = numberOfStatusItems
		}
		
		if let widthOfStatusItem = UserDefaults.standard.object(forKey: Constants.UserPrefs.widthOfStatusItem) as? CGFloat{
			self.widthOfStatusItem = widthOfStatusItem
		}
		
		if let sortingMethodInt = UserDefaults.standard.object(forKey: Constants.UserPrefs.sortingMethod) as? Int, let sortingMethod = SortingMethod(rawValue: sortingMethodInt){
			self.sortingMethod = sortingMethod
		}
		
		if let iconSize = UserDefaults.standard.object(forKey: Constants.UserPrefs.iconSize) as? CGFloat{
			self.iconSize = iconSize
		}
		
		if let launchAtLogin = UserDefaults.standard.object(forKey: Constants.UserPrefs.launchAtLogin) as? Bool{
			self.launchAtLogin = launchAtLogin
		}
		if let launchInsteadOfActivate = UserDefaults.standard.object(forKey: Constants.UserPrefs.launchInsteadOfActivate) as? Bool{
			self.launchInsteadOfActivate = launchInsteadOfActivate
		}
		if let launchInsteadOfActivateIndivApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.launchInsteadOfActivateIndivApps) as? [String: Bool]{
			self.launchInsteadOfActivateIndivApps = launchInsteadOfActivateIndivApps
		}
		if let hideActiveApp = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideActiveApp) as? Bool{
			self.hideActiveApp = hideActiveApp
		}
		if let hideFinder = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideFinder) as? Bool{
			self.hideFinder = hideFinder
		}
	} 
}
