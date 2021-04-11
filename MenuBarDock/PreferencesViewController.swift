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

protocol PreferencesViewControllerDelegate: AnyObject {
	func maxNumRunningAppsSliderEndedChanging(_ value: Int)
	func statusItemWidthSliderDidChange(_ value: Double)
	func appIconSizeSliderDidChange(_ value: Double)

	// TODO: - add all other ui changes
}

class PreferencesViewController: NSViewController { // this should do onthing

	weak var delegate: PreferencesViewControllerDelegate?
	weak var userPrefs: UserPrefs!

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
	@IBOutlet weak var hideActiveAppFromRunningAppsButton: NSButton!
	@IBOutlet weak var hideFinderFromRunningAppsButton: NSButton!

	@IBOutlet weak var launchInsteadOfActivateRadioButton: NSButton!

	override func viewWillAppear() {
		super.viewWillAppear()
		updateUI(for: userPrefs)
	}

	func updateUI(for userPrefs: UserPrefs) {
		self.title = Constants.App.name + " Preferences"
		numberOfAppsCounterLabel.stringValue = "\(userPrefs.maxNumRunningApps)"
		numberOfAppsSlider.integerValue = userPrefs.maxNumRunningApps
		widthOfItemCouterLabel.stringValue = "\(Int(userPrefs.statusItemWidth.rounded()))"
		widthOfItemSlider.doubleValue = Double(userPrefs.statusItemWidth)
		sizeOfIconCounterLabel.stringValue = "\(Int(userPrefs.appIconSize.rounded()))"
		sizeOfIconSlider.doubleValue = Double(userPrefs.appIconSize)
		launchAtLoginButton.state = userPrefs.launchAtLogin ? .on : .off
		//		launchInsteadOfActivateRadioButton.state = userPrefs.launchInsteadOfActivate ? .on : .off  //TODO: - do this
		hideActiveAppFromRunningAppsButton.state = userPrefs.hideActiveAppFromRunningApps ? .on : .off
		hideFinderFromRunningAppsButton.state = userPrefs.hideFinderFromRunningApps ? .on : .off

		switch userPrefs.runningAppsSortingMethod {
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
			sliderChanged: { (value) in
				self.delegate?.statusItemWidthSliderDidChange(value)
			}
		)
	}

	@IBAction func sizeOfIconSliderChange(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: sizeOfIconCounterLabel,
			sliderChanged: { (value) in
				self.delegate?.appIconSizeSliderDidChange(value)
			}
		)
	}

	@IBAction func numberOfAppsSliderChanged(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: numberOfAppsCounterLabel,
			sliderEndedChanging: { value in
				self.delegate?.maxNumRunningAppsSliderEndedChanging(Int(value))

			}
		)
	}

	@IBAction func radioButtonPressed(_ sender: Any) {
//		if consistentSortOrderRadioButton.state == .on {
//			MenuBarDock.shared.userPrefs.runningAppsSortingMethod = .consistent
//		}
//		if mostRecentLeftRadioButton.state == .on {
//			MenuBarDock.shared.userPrefs.runningAppsSortingMethod = .mostRecentOnLeft
//		}
//		if mostRecentRightRadioButton.state == .on {
//			MenuBarDock.shared.userPrefs.runningAppsSortingMethod = .mostRecentOnRight
//		}
//		NotificationCenter.default.post(name: .runningAppsSortingMethodChanged, object: nil)
//		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func resetToDefaultPressed(_ sender: Any) {
//		MenuBarDock.shared.userPrefs.resetToDefaults()
//		updateUI(for: MenuBarDock.shared.userPrefs)
//		NotificationCenter.default.post(name: .resetToDefaults, object: nil)
	}

	@IBAction func resetIndivAppSettings(_ sender: Any) {
//		MenuBarDock.shared.userPrefs.resetIndivAppSettingsToDefaults()
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
//		MenuBarDock.shared.userPrefs.launchAtLogin = sender.state == .on
//		let launcherAppId = Constants.App.launcherBundleId
//		SMLoginItemSetEnabled(launcherAppId as CFString, MenuBarDock.shared.userPrefs.launchAtLogin)
//
//		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func launchInsteadOfActivatingPressed(_ sender: NSButton) {
		//		MenuBarDock.shared.userPrefs.launchInsteadOfActivate = sender.state == .on //TODO: - do this
//		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func hideActiveAppFromRunningAppsPressed(_ sender: NSButton) {
//		MenuBarDock.shared.userPrefs.hideActiveAppFromRunningApps = sender.state == .on
//		MenuBarDock.shared.userPrefs.save()
	}

	@IBAction func hideFinderFromRunningAppsPressed(_ sender: NSButton) {
//		MenuBarDock.shared.userPrefs.hideFinderFromRunningApps = sender.state == .on
//		MenuBarDock.shared.userPrefs.save()
	}

	private func handleSliderChanged(
		slider: NSSlider,
		sliderLabel: NSTextField,
		sliderChanged: ((_ value: Double) -> Void)? = nil,
		sliderEndedChanging: ((_ value: Double) -> Void)? = nil
	) {
		let event = NSApplication.shared.currentEvent
		let startingDrag = event?.type == .leftMouseDown
		let endingDrag = event?.type == .leftMouseUp
		let dragging = event?.type == .leftMouseDragged

		if !(startingDrag || endingDrag || dragging) { return }

		sliderChanged?(slider.doubleValue)

		sliderLabel.stringValue = "\(slider.integerValue)"

		if endingDrag {
			sliderEndedChanging?(slider.doubleValue)
		}
	}

}
