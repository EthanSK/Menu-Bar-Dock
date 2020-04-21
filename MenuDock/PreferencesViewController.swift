//
//  ViewController.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa
import CoreGraphics
import ServiceManagement

class PreferencesViewController: NSViewController { //this should do onthing
	@IBOutlet weak var popoverTitle: NSTextFieldCell!
	
	@IBOutlet weak var numberOfAppsSlider: NSSlider!
	
	@IBOutlet weak var widthOfItemSlider: NSSlider!
	
	@IBOutlet weak var numberOfAppsCounterLabel: NSTextField!
	
	@IBOutlet weak var widthOfItemCouterLabel: NSTextField!
	
	@IBOutlet weak var sizeOfIconSlider: NSSlider!
	
	@IBOutlet weak var sizeOfIconCounterLabel: NSTextField!
	@IBOutlet weak var launchInsteadOfActivateRadioButton: NSButton!
	
	
	@IBOutlet weak var consistentSortOrderRadioButton: NSButton!
	@IBOutlet weak var mostRecentRightRadioButton: NSButton!
	@IBOutlet weak var mostRecentLeftRadioButton: NSButton!
	@IBOutlet weak var launchAtLoginButton: NSButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
	}
	override func viewWillAppear() {
		super.viewDidAppear()
		updateUI()
	}
	
	func updateUI(){
		self.title = Constants.App.name
			+ " Preferences"
		numberOfAppsCounterLabel.stringValue = "\(MenuDock.shared.userPrefs.numberOfStatusItems)"
		numberOfAppsSlider.integerValue = MenuDock.shared.userPrefs.numberOfStatusItems
		widthOfItemCouterLabel.stringValue = "\(Int(MenuDock.shared.userPrefs.widthOfStatusItem.rounded()))"
		widthOfItemSlider.doubleValue = Double(MenuDock.shared.userPrefs.widthOfStatusItem)
		sizeOfIconCounterLabel.stringValue = "\(Int(MenuDock.shared.userPrefs.iconSize.rounded()))"
		sizeOfIconSlider.doubleValue = Double(MenuDock.shared.userPrefs.iconSize)
		launchAtLoginButton.state = MenuDock.shared.userPrefs.launchAtLogin ? .on : .off
		launchInsteadOfActivateRadioButton.state = MenuDock.shared.userPrefs.launchInsteadOfActivate ? .on : .off
		switch MenuDock.shared.userPrefs.sortingMethod {
		case .mostRecentOnRight:
			mostRecentRightRadioButton.state = .on
		case .mostRecentOnLeft:
			mostRecentLeftRadioButton.state = .on
		case .consistent:
			consistentSortOrderRadioButton.state = .on
		}
		
	}
	
	@IBAction func widthOfItemSliderChanged(_ sender: NSSlider) {
		let event: NSEvent? = NSApplication.shared.currentEvent
		let startingDrag: Bool = event?.type == .leftMouseDown
		let endingDrag: Bool = event?.type == .leftMouseUp
		let dragging: Bool = event?.type == .leftMouseDragged
		
		
		if let event = event {
			assert(startingDrag || endingDrag || dragging, "unexpected event type caused slider change: \(event)")
		}
		
		if startingDrag {
			print("widthOfItemSliderChanged value started changing")
			// do whatever needs to be done when the slider starts changing
		}
		
		MenuDock.shared.userPrefs.widthOfStatusItem = CGFloat(sender.doubleValue)
		NotificationCenter.default.post(name: .widthOfitemSliderChanged, object: nil)
		widthOfItemCouterLabel.stringValue = "\(sender.integerValue)"
		
		if endingDrag {
			print("slider value stopped changing")
			NotificationCenter.default.post(name: .widthOfitemSliderEndedSliding, object: nil)
			
			MenuDock.shared.userPrefs.save()
		}
	}
	
	@IBAction func sizeOfIconSliderChange(_ sender: NSSlider) {
		let event: NSEvent? = NSApplication.shared.currentEvent
		let startingDrag: Bool = event?.type == .leftMouseDown
		let endingDrag: Bool = event?.type == .leftMouseUp
		let dragging: Bool = event?.type == .leftMouseDragged
		
		
		if let event = event {
			assert(startingDrag || endingDrag || dragging, "unexpected event type caused slider change: \(event)")
		}
		
		if startingDrag {
			print("sizeOfIconSliderChange value started changing")
			// do whatever needs to be done when the slider starts changing
		}
		
		MenuDock.shared.userPrefs.iconSize = CGFloat(sender.doubleValue)
		NotificationCenter.default.post(name: .sizeOfIconSliderChanged, object: nil)
		sizeOfIconCounterLabel.stringValue = "\(sender.integerValue)"
		
		if endingDrag {
			print("slider value stopped changing")
			NotificationCenter.default.post(name: .sizeOfIconSliderEndedSliding, object: nil)
			MenuDock.shared.userPrefs.save()
		}
	}
	
	
	@IBAction func numberOfAppsSliderChanged(_ sender: NSSlider) {
		
		let event: NSEvent? = NSApplication.shared.currentEvent
		let startingDrag: Bool = event?.type == .leftMouseDown
		let endingDrag: Bool = event?.type == .leftMouseUp
		let dragging: Bool = event?.type == .leftMouseDragged
		
		if let event = event {
			assert(startingDrag || endingDrag || dragging, "unexpected event type caused slider change: \(event)")
		}
		
		if startingDrag {
			print("numberOfAppsSliderChanged value started changing")
			// do whatever needs to be done when the slider starts changing
		}
		
		MenuDock.shared.userPrefs.numberOfStatusItems = sender.integerValue
		NotificationCenter.default.post(name: .numberOfAppsSliderChanged, object: nil)
		numberOfAppsCounterLabel.stringValue = "\(sender.integerValue)"
		
		if endingDrag {
			print("slider value stopped changing")
			NotificationCenter.default.post(name: .numberOfAppsSliderEndedSliding, object: nil)
			
			MenuDock.shared.userPrefs.save()
		}
	}
	
	@IBAction func radioButtonPressed(_ sender: Any) {
		print("sortingRadioButtons state ", consistentSortOrderRadioButton.state, mostRecentLeftRadioButton.state, mostRecentRightRadioButton.state)
		if consistentSortOrderRadioButton.state == .on{
			MenuDock.shared.userPrefs.sortingMethod = .consistent
		}
		if mostRecentLeftRadioButton.state == .on{
			MenuDock.shared.userPrefs.sortingMethod = .mostRecentOnLeft
		}
		if mostRecentRightRadioButton.state == .on{
			MenuDock.shared.userPrefs.sortingMethod = .mostRecentOnRight
		}
		NotificationCenter.default.post(name: .sortingMethodChanged, object: nil)

		MenuDock.shared.userPrefs.save()
	}
	
	
	@IBAction func resetToDefaultPressed(_ sender: Any) {
		MenuDock.shared.userPrefs.resetToDefaults()
		updateUI()
		NotificationCenter.default.post(name: .resetToDefaults, object: nil)

	}
	
	@IBAction func aboutPressed(_ sender: Any) {
		if let url = URL(string: "https://www.etggames.com/menu-bar-dock"), 
			NSWorkspace.shared.open(url) {
			print("default browser was successfully opened")
		}
	}
	
	@IBAction func logoPressed(_ sender: Any) {
		if let url = URL(string: "https://www.etggames.com"),
			NSWorkspace.shared.open(url) {
 		}
	}
	
	@IBAction func launchAtLoginPressed(_ sender: NSButton) {
		MenuDock.shared.userPrefs.launchAtLogin = sender.state == .on
		let launcherAppId = "com.etggames.Launcher"
		let result = SMLoginItemSetEnabled(launcherAppId as CFString, MenuDock.shared.userPrefs.launchAtLogin) 
		print("login item res: ", result)
	
		MenuDock.shared.userPrefs.save()
	}
	
	@IBAction func launchInsteadOfActivatingPressed(_ sender: NSButton) {
		MenuDock.shared.userPrefs.launchInsteadOfActivate = sender.state == .on
		
		MenuDock.shared.userPrefs.save()
	}
	
}//class

extension PreferencesViewController {
	// MARK: Storyboard instantiation
	static func freshController() -> PreferencesViewController {
		//1.
		let storyboard = NSStoryboard(name: "Main",bundle: nil)
		//2.
		let identifier = "preferences"
		//3.
		guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? PreferencesViewController else {
			fatalError("cant find vc")
		}
		return viewcontroller
	}
}
