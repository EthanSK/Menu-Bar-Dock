//
//  ViewController.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa
import CoreGraphics
import ServiceManagement

class PreferencesViewController: NSViewController { // this should do onthing

	@IBOutlet weak var numberOfAppsSlider: NSSlider!
	@IBOutlet weak var widthOfItemSlider: NSSlider!
	@IBOutlet weak var sizeOfIconSlider: NSSlider!

	@IBOutlet weak var numberOfAppsCounterLabel: NSTextField!
	@IBOutlet weak var widthOfItemCouterLabel: NSTextField!
	@IBOutlet weak var sizeOfIconCounterLabel: NSTextField!

	@IBOutlet weak var consistentSortOrderRadioButton: NSButton!
	@IBOutlet weak var mostRecentRightRadioButton: NSButton!
	@IBOutlet weak var mostRecentLeftRadioButton: NSButton!

	@IBOutlet weak var launchAtLoginButton: NSButton!
	@IBOutlet weak var hideActiveAppButton: NSButton!
	@IBOutlet weak var hideFinderButton: NSButton!

	@IBOutlet weak var launchInsteadOfActivateRadioButton: NSButton!
	
	override func viewWillAppear() {
		super.viewWillAppear()
		updateUI(for: MenuBarDock.shared.userPrefs)
	}

	func updateUI(for userPrefs: UserPrefs) {
		self.title = Constants.App.name + " Preferences"
		numberOfAppsCounterLabel.stringValue = "\(userPrefs.numberOfStatusItems)"
		numberOfAppsSlider.integerValue = userPrefs.numberOfStatusItems
		widthOfItemCouterLabel.stringValue = "\(Int(userPrefs.widthOfStatusItem.rounded()))"
		widthOfItemSlider.doubleValue = Double(userPrefs.widthOfStatusItem)
		sizeOfIconCounterLabel.stringValue = "\(Int(userPrefs.iconSize.rounded()))"
		sizeOfIconSlider.doubleValue = Double(userPrefs.iconSize)
		launchAtLoginButton.state = userPrefs.launchAtLogin ? .on : .off
		launchInsteadOfActivateRadioButton.state = userPrefs.launchInsteadOfActivate ? .on : .off
		hideActiveAppButton.state = userPrefs.hideActiveApp ? .on : .off
		hideFinderButton.state = userPrefs.hideFinder ? .on : .off

		switch userPrefs.sortingMethod {
		case .mostRecentOnRight:
			mostRecentRightRadioButton.state = .on
		case .mostRecentOnLeft:
			mostRecentLeftRadioButton.state = .on
		case .consistent:
			consistentSortOrderRadioButton.state = .on
		}
	}
	
	@IBAction func widthOfItemSliderChanged(_ sender: NSSlider) {
 		handleSliderChanged(
			slider: sender,
			sliderLabel: widthOfItemCouterLabel,
			newValueNotifName: .widthOfitemSliderChanged,
			endedDragNotifName: .widthOfitemSliderEndedSliding,
			sliderNewValue: { value in
				MenuBarDock.shared.userPrefs.widthOfStatusItem = CGFloat(value)
			}
		)
	}

	@IBAction func sizeOfIconSliderChange(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: sizeOfIconCounterLabel,
			newValueNotifName: .sizeOfIconSliderChanged,
			endedDragNotifName: .sizeOfIconSliderEndedSliding,
			sliderNewValue: { value in
				MenuBarDock.shared.userPrefs.iconSize = CGFloat(value)
			}
		)
	}

	@IBAction func numberOfAppsSliderChanged(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: numberOfAppsCounterLabel,
			newValueNotifName: .numberOfAppsSliderChanged,
			endedDragNotifName: .numberOfAppsSliderEndedSliding,
			sliderNewValue: { value in
				MenuBarDock.shared.userPrefs.numberOfStatusItems = Int(value)
			}
		)
	}

	@IBAction func radioButtonPressed(_ sender: Any) {
		if consistentSortOrderRadioButton.state == .on {
			MenuBarDock.shared.userPrefs.sortingMethod = .consistent
		}
		if mostRecentLeftRadioButton.state == .on {
			MenuBarDock.shared.userPrefs.sortingMethod = .mostRecentOnLeft
		}
		if mostRecentRightRadioButton.state == .on {
			MenuBarDock.shared.userPrefs.sortingMethod = .mostRecentOnRight
		}
		NotificationCenter.default.post(name: .sortingMethodChanged, object: nil)
		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func resetToDefaultPressed(_ sender: Any) {
		MenuBarDock.shared.userPrefs.resetToDefaults()
		updateUI(for: MenuBarDock.shared.userPrefs)
		NotificationCenter.default.post(name: .resetToDefaults, object: nil)
	}

	@IBAction func resetIndivAppSettings(_ sender: Any) {
		MenuBarDock.shared.userPrefs.resetIndivAppSettingsToDefaults()
	}

	@IBAction func aboutPressed(_ sender: Any) {
		if let url = URL(string: "https://www.etggames.com/menu-bar-dock"),
			NSWorkspace.shared.open(url) {
		}
	}

	@IBAction func logoPressed(_ sender: Any) {
		if let url = URL(string: "https://www.etggames.com"),
			NSWorkspace.shared.open(url) {
 		}
	}

	@IBAction func launchAtLoginPressed(_ sender: NSButton) {
		MenuBarDock.shared.userPrefs.launchAtLogin = sender.state == .on
		let launcherAppId = Constants.App.launcherBundleId
		SMLoginItemSetEnabled(launcherAppId as CFString, MenuBarDock.shared.userPrefs.launchAtLogin)

		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func launchInsteadOfActivatingPressed(_ sender: NSButton) {
		MenuBarDock.shared.userPrefs.launchInsteadOfActivate = sender.state == .on
		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func hideActiveAppPressed(_ sender: NSButton) {
		MenuBarDock.shared.userPrefs.hideActiveApp = sender.state == .on
		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func hideFinderPressed(_ sender: NSButton) {
		MenuBarDock.shared.userPrefs.hideFinder = sender.state == .on
		MenuBarDock.shared.userPrefs.save()
	}
	
	private func handleSliderChanged(
		slider: NSSlider,
		sliderLabel: NSTextField,
		newValueNotifName: NSNotification.Name,
		endedDragNotifName: NSNotification.Name,
		sliderNewValue: @escaping (_ value: Double) -> Void
	) {
		let event = NSApplication.shared.currentEvent
		let startingDrag = event?.type == .leftMouseDown
		let endingDrag = event?.type == .leftMouseUp
		let dragging = event?.type == .leftMouseDragged

		if !(startingDrag || endingDrag || dragging) { return }

		sliderNewValue(slider.doubleValue)
		NotificationCenter.default.post(name: newValueNotifName, object: nil)
		sliderLabel.stringValue = "\(slider.integerValue)"

		if endingDrag {
			NotificationCenter.default.post(name: endedDragNotifName, object: nil)
			MenuBarDock.shared.userPrefs.save()
		}
	}

}

extension PreferencesViewController {
	static func freshController() -> PreferencesViewController {
 		let storyboard = NSStoryboard(name: "Main", bundle: nil)
 		let identifier = "preferences"
 		guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? PreferencesViewController else {
			fatalError("Can't find view controller with identifier " + identifier)
		}
		return viewcontroller
	}
}
