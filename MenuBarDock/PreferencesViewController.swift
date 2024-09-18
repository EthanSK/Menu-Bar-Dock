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
	func runningAppsSortingMethodDidChange(_ value: RunningAppsSortingMethod)
	func resetPreferencesToDefaultsWasPressed()
	func resetAppOpeningMethodsWasPressed()
	func launchAtLoginDidChange(_ value: Bool)
	func aboutWasPressed()
	func hideFinderDidChange(_ value: Bool)
	func hideActiveAppDidChange(_ value: Bool)
    func preserveAppOrderDidChange(_ value: Bool)
	func appOpeningMethodDidChange(_ value: AppOpeningMethod)
	func regularAppsUrlsWereAdded(_ value: [URL])
	func regularAppsUrlsWereRemoved(_ removedIndexes: IndexSet)
	func regularAppUrlWasMoved(oldIndex: Int, newIndex: Int)
	func sideToShowRunningAppsDidChange(_ value: SideToShowRunningApps)
	func hideDuplicateAppsWasPressed(_ value: Bool)
	func duplicateAppsPriorityDidChange(_ value: DuplicateAppsPriority)
	func infoWasPressed()
}

protocol PreferencesViewControllerUserPrefsDataSource: AnyObject {
	var maxNumRunningApps: Int { get }
	var statusItemWidth: CGFloat { get }
	var runningAppsSortingMethod: RunningAppsSortingMethod { get }
	var appIconSize: CGFloat { get }
	var launchAtLogin: Bool { get }
	var defaultAppOpeningMethod: AppOpeningMethod { get }
	var hideFinderFromRunningApps: Bool { get }
	var hideActiveAppFromRunningApps: Bool { get }
    var preserveAppOrder: Bool { get }
	var regularAppsUrls: [URL] { get }
	var sideToShowRunningApps: SideToShowRunningApps { get }
	var hideDuplicateApps: Bool { get }
	var duplicateAppsPriority: DuplicateAppsPriority { get }
}

class PreferencesViewController: NSViewController { // this should do nothing
	weak var delegate: PreferencesViewControllerDelegate?
	weak var userPrefsDataSource: PreferencesViewControllerUserPrefsDataSource!

	@IBOutlet weak var maxNumRunningAppsSlider: NSSlider!
	@IBOutlet weak var statusItemWidthSlider: NSSlider!
	@IBOutlet weak var appIconSizeSlider: NSSlider!

	@IBOutlet weak var maxNumRunningAppsCounterLabel: NSTextField!
	@IBOutlet weak var statusItemWidthCounterLabel: NSTextField!
	@IBOutlet weak var appIconSizeCounterLabel: NSTextField!

	@IBOutlet weak var consistentSortOrderRadioButton: NSButton!
	@IBOutlet weak var mostRecentRightRadioButton: NSButton!
	@IBOutlet weak var mostRecentLeftRadioButton: NSButton!

	@IBOutlet weak var appOpeningMethodPopUp: NSPopUpButton!

	@IBOutlet weak var hideActiveAppFromRunningAppsButton: NSButton!
	@IBOutlet weak var hideFinderFromRunningAppsButton: NSButton!
    @IBOutlet weak var preserveAppOrderButton: NSButton!

	@IBOutlet weak var sideToShowRunningAppsControl: NSSegmentedControl!

	@IBOutlet weak var hideDuplicateAppsButton: NSButton!
	@IBOutlet weak var duplicateAppsPriorityControl: NSSegmentedControl!

	@IBOutlet weak var launchAtLoginButton: NSButton!

	@IBOutlet weak var appsTable: NSTableView!
	@IBOutlet weak var regularAppsHintLabel: NSTextField!

	override func viewDidLoad() {
		super.viewDidLoad()
		appsTable.delegate = self
		appsTable.dataSource = self
		appsTable.doubleAction = #selector(tableRowDoubleClicked)
		appsTable.registerForDraggedTypes([.string])
		updateTable()

	}
	override func viewWillAppear() {
		super.viewWillAppear()
		initAppOpeningMethodPopup()
		updateUi()
	}

	func updateUi() {
		self.title = Constants.App.name + " Preferences"
		maxNumRunningAppsCounterLabel.stringValue = "\(userPrefsDataSource.maxNumRunningApps)"

		maxNumRunningAppsSlider.integerValue = userPrefsDataSource.maxNumRunningApps

		statusItemWidthCounterLabel.stringValue = "\(Int(userPrefsDataSource.statusItemWidth.rounded()))"

		statusItemWidthSlider.doubleValue = Double(userPrefsDataSource.statusItemWidth)

		appIconSizeCounterLabel.stringValue = "\(Int(userPrefsDataSource.appIconSize.rounded()))"

		appIconSizeSlider.doubleValue = Double(userPrefsDataSource.appIconSize)
		launchAtLoginButton.state = userPrefsDataSource.launchAtLogin ? .on : .off

		appOpeningMethodPopUp.selectItem(withTitle: userPrefsDataSource.defaultAppOpeningMethod.rawValue.capitalizingFirstLetter())

		hideActiveAppFromRunningAppsButton.state = userPrefsDataSource.hideActiveAppFromRunningApps ? .on : .off

		hideFinderFromRunningAppsButton.state = userPrefsDataSource.hideFinderFromRunningApps ? .on : .off

        preserveAppOrderButton.state = userPrefsDataSource.preserveAppOrder ? .on : .off

		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight:
			mostRecentRightRadioButton.state = .on
		case .mostRecentOnLeft:
			mostRecentLeftRadioButton.state = .on
		case .consistent:
			consistentSortOrderRadioButton.state = .on
		}

		switch userPrefsDataSource.sideToShowRunningApps {
		case .left:
			sideToShowRunningAppsControl.selectedSegment = 0
		case .right:
			sideToShowRunningAppsControl.selectedSegment = 1
		}

		hideDuplicateAppsButton.state = userPrefsDataSource.hideDuplicateApps ? .on : .off

		switch userPrefsDataSource.duplicateAppsPriority {
		case .runningApps:
			duplicateAppsPriorityControl.selectedSegment = 0
		case .regularApps:
			duplicateAppsPriorityControl.selectedSegment = 1
		}

		duplicateAppsPriorityControl.isEnabled = userPrefsDataSource.hideDuplicateApps

		if userPrefsDataSource.regularAppsUrls.count > 0 {
			regularAppsHintLabel.stringValue = "Drag apps to reorder them!"
		} else {
			regularAppsHintLabel.stringValue = "Click + to add some apps!"
		}
	}

	private func initAppOpeningMethodPopup() {
		appOpeningMethodPopUp.removeAllItems()
		appOpeningMethodPopUp.addItems(withTitles: [
			AppOpeningMethod.launch.rawValue.capitalizingFirstLetter(),
			AppOpeningMethod.activate.rawValue.capitalizingFirstLetter()
		])
	}

	@IBAction func statusItemWidthSliderChanged(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: statusItemWidthCounterLabel,
			sliderChanged: { (value) in
				self.delegate?.statusItemWidthSliderDidChange(value)
			}
		)
	}

	@IBAction func appIconSizeSliderChange(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: appIconSizeCounterLabel,
			sliderChanged: { (value) in
				self.delegate?.appIconSizeSliderDidChange(value)
			}
		)
	}

	@IBAction func numberOfAppsSliderChanged(_ sender: NSSlider) {
		handleSliderChanged(
			slider: sender,
			sliderLabel: maxNumRunningAppsCounterLabel,
			sliderEndedChanging: { value in
				self.delegate?.maxNumRunningAppsSliderEndedChanging(Int(value))

			}
		)
	}

	@IBAction func radioButtonPressed(_ sender: Any) {
		var value: RunningAppsSortingMethod?
		if consistentSortOrderRadioButton.state == .on {
			value = .consistent
		}
		if mostRecentLeftRadioButton.state == .on {
			value = .mostRecentOnLeft
		}
		if mostRecentRightRadioButton.state == .on {
			value = .mostRecentOnRight
		}
		if let value = value {
			delegate?.runningAppsSortingMethodDidChange(value)
		}
	}

	@IBAction func resetPreferencesToDefaultsPressed(_ sender: Any) {
		showResetConfirmationAlert(title: "Warning", message: "You are about to reset all the preferences for \(Constants.App.name). The '\(Constants.App.regularAppsSectionTitle)' table will not be reset. Are you sure you want to proceed?") { (result) in
			if result {
				delegate?.resetPreferencesToDefaultsWasPressed()
				updateUi() // show updated user prefs
			}
		}
	}

	@IBAction func resetAppOpeningMethodsPressed(_ sender: Any) {
		showResetConfirmationAlert(title: "Warning", message: "You are about to reset all the individual app opening methods you may have previously set. Are you sure you want to proceed?") { (result) in
			if result {
				delegate?.resetAppOpeningMethodsWasPressed()
			}
		}
	}

	@IBAction func aboutPressed(_ sender: Any) {
		delegate?.aboutWasPressed()
	}

	@IBAction func launchAtLoginPressed(_ sender: NSButton) {
		delegate?.launchAtLoginDidChange(sender.state == .on)
	}

	@IBAction func appOpeningMethodChanged(_ sender: NSPopUpButton) {
		let value = AppOpeningMethod(rawValue: sender.selectedItem?.title.lowercased() ?? "")
		if let value = value {
			delegate?.appOpeningMethodDidChange(value)
		}
	}

	@IBAction func hideActiveAppFromRunningAppsPressed(_ sender: NSButton) {
		delegate?.hideActiveAppDidChange(sender.state == .on)
	}

	@IBAction func hideFinderFromRunningAppsPressed(_ sender: NSButton) {
		delegate?.hideFinderDidChange(sender.state == .on)
	}

    @IBAction func preserveAppOrderPressed(_ sender: NSButton) {
        delegate?.preserveAppOrderDidChange(sender.state == .on)
    }

	@IBAction func addOrRemovePressed(_ sender: NSSegmentedControl) {
		switch sender.selectedSegment {
		case 0:
			showFileExplorerToAddApps()
		case 1:
			removeSelectedApps()
		default:
			break
		}
	}

	@IBAction func showRunningAppsOnLeftOrRightSelected(_ sender: NSSegmentedControl) {
		switch sender.selectedSegment {
		case 0:
			delegate?.sideToShowRunningAppsDidChange(.left)
		case 1:
			delegate?.sideToShowRunningAppsDidChange(.right)
		default:
			break
		}
	}

	@IBAction func hideDuplicateAppsPressed(_ sender: NSButton) {
		delegate?.hideDuplicateAppsWasPressed(sender.state == .on)
		updateUi() // to show or hide duplicate apps priority control
	}

	@IBAction func duplicateAppsPrioritySelected(_ sender: NSSegmentedControl) {
		switch sender.selectedSegment {
		case 0:
			delegate?.duplicateAppsPriorityDidChange(.runningApps)
		case 1:
			delegate?.duplicateAppsPriorityDidChange(.regularApps)
		default:
			break
		}
	}

	@IBAction func infoPressed(_ sender: NSButton) {
		delegate?.infoWasPressed()
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

	private func showFileExplorerToAddApps() {
		let dialog = NSOpenPanel()

		dialog.title = "Select some apps"
		dialog.showsResizeIndicator = true
		dialog.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
		dialog.showsHiddenFiles = false
		dialog.allowsMultipleSelection = true
		dialog.canChooseDirectories = false
		dialog.canChooseFiles = true
		dialog.allowedFileTypes = ["app"]

		if dialog.runModal() == NSApplication.ModalResponse.OK {
			delegate?.regularAppsUrlsWereAdded(dialog.urls)
			updateTable()
			updateUi()
		} else {
			// User clicked on "Cancel"
			return
		}
	}

	private func removeSelectedApps() {
		delegate?.regularAppsUrlsWereRemoved(appsTable.selectedRowIndexes)
		updateTable()
		updateUi()
	}

	private func updateTable() {
		appsTable.reloadData()
	}

	@objc private func tableRowDoubleClicked() {
		NSWorkspace.shared.activateFileViewerSelecting([userPrefsDataSource.regularAppsUrls[appsTable.clickedRow]]) // reveal in finder
	}

	private func showResetConfirmationAlert(title: String, message: String, completion: (Bool) -> Void) {
		let alert = NSAlert()
		alert.messageText = title
		alert.informativeText = message
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Reset")
		alert.addButton(withTitle: "Cancel")
		completion(alert.runModal() == .alertFirstButtonReturn)
	}
}
