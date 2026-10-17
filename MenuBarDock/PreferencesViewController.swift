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
    // Running Apps
    func runningAppsSortingMethodDidChange(_ value: RunningAppsSortingMethod)
    func hideFinderDidChange(_ value: Bool)
    func hideActiveAppDidChange(_ value: Bool)
    func hideDuplicateAppsDidChange(_ value: Bool)
    func preserveAppOrderDidChange(_ value: Bool)
    func rightClickByDefaultDidChange(_ value: Bool)

    // Regular Apps
    func regularAppsUrlsWereAdded(_ value: [URL])
    func regularAppsUrlsWereRemoved(_ removedIndexes: IndexSet)
    func regularAppsUrlsWereReordered(_ urls: [URL])
    func appIconOverrideDidChange(_ imageData: Data?, forAppAt url: URL)

    // General
    func infoWasPressed()
    func itemSlotWidthSliderDidChange(_ value: Double)
    func appIconSizeSliderDidChange(_ value: Double)
    func groupSpacingSliderDidChange(_ value: Double)
    func hoverAnimationsDidChange(_ value: Bool)
    func groupBackgroundDidChange(_ value: Bool)
    func restartAppWasPressed()
    func maxRunningAppsSliderDidChange(_ value: Int)
    func sideToShowRunningAppsDidChange(_ value: SideToShowRunningApps)
    func duplicateAppsPriorityDidChange(_ value: DuplicateAppsPriority)
    func appOpeningMethodDidChange(_ value: AppOpeningMethod)

    // Bottom
    func aboutWasPressed()
    func resetPreferencesToDefaultsWasPressed()
    func resetAppOpeningMethodsWasPressed()
    func checkForUpdatesWasPressed(_ sender: Any?)
    func launchAtLoginDidChange(_ value: Bool)
}

protocol PreferencesViewControllerUserPrefsDataSource: AnyObject {
    // Running Apps
    var runningAppsSortingMethod: RunningAppsSortingMethod { get }
    var hideFinderFromRunningApps: Bool { get }
    var hideActiveAppFromRunningApps: Bool { get }
    var hideDuplicateApps: Bool { get }
    var preserveAppOrder: Bool { get }
    var rightClickByDefault: Bool { get }

    // Regular Apps
    var regularAppsUrls: [URL] { get }
    func iconOverride(forAppAt url: URL) -> NSImage?

    // General
    var itemSlotWidth: CGFloat { get }
    var appIconSize: CGFloat { get }
    var groupSpacing: CGFloat { get }
    var hoverAnimationsEnabled: Bool { get }
    var groupBackgroundEnabled: Bool { get }
    var maxRunningApps: Int { get }
    var sideToShowRunningApps: SideToShowRunningApps { get }
    var duplicateAppsPriority: DuplicateAppsPriority { get }
    var defaultAppOpeningMethod: AppOpeningMethod { get }

    // Bottom
    var launchAtLogin: Bool { get }
}

class PreferencesViewController: NSViewController { // this should do nothing
	weak var delegate: PreferencesViewControllerDelegate?
	weak var userPrefsDataSource: PreferencesViewControllerUserPrefsDataSource!

    // Running Apps
    @IBOutlet weak var mostRecentRightRadioButton: NSButton!
    @IBOutlet weak var mostRecentLeftRadioButton: NSButton!
    @IBOutlet weak var consistentSortOrderRadioButton: NSButton!
    @IBOutlet weak var hideFinderFromRunningAppsButton: NSButton!
    @IBOutlet weak var hideActiveAppFromRunningAppsButton: NSButton!
    @IBOutlet weak var hideDuplicateAppsButton: NSButton!
    @IBOutlet weak var preserveAppOrderButton: NSButton!
    @IBOutlet weak var rightClickByDefaultButton: NSButton!

    // Regular Apps
    @IBOutlet weak var regularAppsTable: NSTableView!
    @IBOutlet weak var regularAppsHintLabel: NSTextField!

    // General
    @IBOutlet weak var itemSlotWidthCounterLabel: NSTextField!
    @IBOutlet weak var itemSlotWidthSlider: NSSlider!
    @IBOutlet weak var appIconSizeCounterLabel: NSTextField!
    @IBOutlet weak var appIconSizeSlider: NSSlider!
    @IBOutlet weak var maxRunningAppsCounterLabel: NSTextField!
	@IBOutlet weak var maxRunningAppsSlider: NSSlider!
    @IBOutlet weak var sideToShowRunningAppsControl: NSSegmentedControl!
    @IBOutlet weak var duplicateAppsPriorityControl: NSSegmentedControl!

    // Bottom
	@IBOutlet weak var appOpeningMethodPopUp: NSPopUpButton!
	@IBOutlet weak var launchAtLoginButton: NSButton!
    private(set) var groupSpacingSlider: NSSlider!
    private(set) var groupSpacingCounterLabel: NSTextField!
    private(set) var hoverAnimationsButton: NSButton!
    private(set) var groupBackgroundButton: NSButton!
    private(set) var restartAppButton: NSButton!

	override func viewDidLoad() {
		super.viewDidLoad()
		regularAppsTable.delegate = self
		regularAppsTable.dataSource = self
		regularAppsTable.doubleAction = #selector(tableRowDoubleClicked)
        regularAppsTable.registerForDraggedTypes([Self.pinnedRowPasteboardType])
		let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppActions"))
		actionsColumn.width = 36
		actionsColumn.minWidth = 36
		actionsColumn.maxWidth = 36
		actionsColumn.resizingMask = []
		regularAppsTable.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle // Keep the fixed-width icon menu visible when the scroll view lays out its app column.
		regularAppsTable.addTableColumn(actionsColumn)
		regularAppsTable.tableColumns[0].width = regularAppsTable.enclosingScrollView!.contentSize.width - actionsColumn.width - regularAppsTable.intercellSpacing.width * CGFloat(regularAppsTable.tableColumns.count)
		itemSlotWidthSlider.minValue = 30
        itemSlotWidthSlider.maxValue = 64
        itemSlotWidthSlider.toolTip = "Minimum button width. Large icons automatically widen the button to keep the running indicator clear."
        appIconSizeSlider.minValue = 12
        appIconSizeSlider.maxValue = 100
        regularAppsTable.tableColumns[0].title = "Apps & Folders"
        renamePinnedSection(in: view)
        addGroupSpacingControl()
        addAppearanceAndRestartControls()
        #if LOCAL_BUILD
        if #unavailable(macOS 13.0) {
            launchAtLoginButton.isEnabled = false
            launchAtLoginButton.toolTip = "Launch at Login in this local build requires macOS 13 or later."
        }
        #endif
        updateTable()
	}

    private func addGroupSpacingControl() {
        // Add to the compiled storyboard too, so local builds need no Xcode.
        let section = sideToShowRunningAppsControl.superview!.superview!
        let bottomBar = launchAtLoginButton.superview!
        let label = NSTextField(labelWithString: "Group right margin:")
        groupSpacingCounterLabel = NSTextField(labelWithString: "48 pt")
        groupSpacingCounterLabel.alignment = .right
        groupSpacingCounterLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        let labels = NSStackView(views: [label, groupSpacingCounterLabel])
        labels.orientation = .horizontal
        labels.distribution = .fill
        labels.spacing = 8
        groupSpacingSlider = NSSlider(value: 48, minValue: 0, maxValue: 160,
                                     target: self, action: #selector(groupSpacingSliderChanged))
        groupSpacingSlider.isContinuous = true
        groupSpacingSlider.setAccessibilityLabel("Group right margin")
        let controls = NSStackView(views: [labels, groupSpacingSlider])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 4
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.toolTip = "Empty space to the right of the dock group, in points. Increase it to move icons farther left. Hold ⌘ and drag the group to change its menu-bar position."
        groupSpacingSlider.toolTip = controls.toolTip
        section.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: sideToShowRunningAppsControl.superview!.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -43),
            controls.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -12),
            labels.widthAnchor.constraint(equalTo: controls.widthAnchor),
            groupSpacingSlider.widthAnchor.constraint(equalTo: controls.widthAnchor)
        ])
    }

    @objc func groupSpacingSliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue.rounded()
        groupSpacingCounterLabel.stringValue = "\(Int(value)) pt"
        delegate?.groupSpacingSliderDidChange(value)
    }

    private func addAppearanceAndRestartControls() {
        // Keep the original compiled storyboard intact and add a separate row
        // below it, with enough height for every control at the native font size.
        let original = view
        let container = NSView(frame: NSRect(origin: .zero,
            size: NSSize(width: original.frame.width, height: original.frame.height + 64)))
        view = container
        original.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(original)
        hoverAnimationsButton = NSButton(checkboxWithTitle: "Animate icons on hover", target: self,
                                         action: #selector(hoverAnimationsChanged))
        hoverAnimationsButton.toolTip = "Move icons down by about 1.5 mm. System Reduce Motion also disables this effect."
        groupBackgroundButton = NSButton(checkboxWithTitle: "Show group background", target: self,
                                         action: #selector(groupBackgroundChanged))
        groupBackgroundButton.toolTip = "Show the rounded background behind the icon group."
        restartAppButton = NSButton(title: "Restart App", target: self, action: #selector(restartAppPressed))
        restartAppButton.bezelStyle = .rounded
        restartAppButton.toolTip = "Save settings and restart this copy of Menu Bar Dock."
        let toggles = NSStackView(views: [hoverAnimationsButton, groupBackgroundButton])
        toggles.orientation = .vertical
        toggles.alignment = .leading
        toggles.spacing = 8
        let actions = NSStackView(views: [restartAppButton])
        actions.orientation = .horizontal
        actions.spacing = 8
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        toggles.translatesAutoresizingMaskIntoConstraints = false
        actions.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(toggles)
        row.addSubview(actions)
        for button in [hoverAnimationsButton!, groupBackgroundButton!] {
            button.widthAnchor.constraint(equalToConstant: button.intrinsicContentSize.width).isActive = true
            button.heightAnchor.constraint(equalToConstant: button.intrinsicContentSize.height).isActive = true
        }
        container.addSubview(row)
        NSLayoutConstraint.activate([
            original.topAnchor.constraint(equalTo: container.topAnchor),
            original.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            original.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            original.heightAnchor.constraint(equalToConstant: original.frame.height),
            row.topAnchor.constraint(equalTo: original.bottomAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            toggles.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            toggles.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            actions.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            actions.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            actions.leadingAnchor.constraint(greaterThanOrEqualTo: toggles.trailingAnchor, constant: 20)
        ])
    }

    @objc func hoverAnimationsChanged(_ sender: NSButton) { delegate?.hoverAnimationsDidChange(sender.state == .on) }
    @objc func groupBackgroundChanged(_ sender: NSButton) { delegate?.groupBackgroundDidChange(sender.state == .on) }
    @objc func restartAppPressed(_ sender: NSButton) { delegate?.restartAppWasPressed() }

    private func renamePinnedSection(in view: NSView) {
        if let label = view as? NSTextField, label.stringValue == "Regular Apps" {
            label.stringValue = "Apps & Folders"
            label.toolTip = "Pin applications and folders with +, then drag rows to reorder them."
        }
        if let label = view as? NSTextField, label.stringValue == "Item Slot Width:" {
            label.stringValue = "Minimum Item Width:"
        }
        view.subviews.forEach { renamePinnedSection(in: $0) }
    }

	override func viewWillAppear() {
		super.viewWillAppear()
		initAppOpeningMethodPopup()
		updateUi()
	}

	func updateUi() {
		self.title = Constants.App.name + " Preferences"

        // Running Apps
        switch userPrefsDataSource.runningAppsSortingMethod {
        case .mostRecentOnRight:
            mostRecentRightRadioButton.state = .on
        case .mostRecentOnLeft:
            mostRecentLeftRadioButton.state = .on
        case .consistent:
            consistentSortOrderRadioButton.state = .on
        }

        hideFinderFromRunningAppsButton.state = userPrefsDataSource.hideFinderFromRunningApps ? .on : .off
        hideActiveAppFromRunningAppsButton.state = userPrefsDataSource.hideActiveAppFromRunningApps ? .on : .off
        hideDuplicateAppsButton.state = userPrefsDataSource.hideDuplicateApps ? .on : .off
        preserveAppOrderButton.state = .on
        preserveAppOrderButton.isEnabled = false
        preserveAppOrderButton.title = "Keep icons grouped"
        preserveAppOrderButton.toolTip = "Icons always move together. Hold ⌘ and drag the group to reposition it."
        rightClickByDefaultButton.state = userPrefsDataSource.rightClickByDefault ? .on : .off

        // Regular Apps
        if userPrefsDataSource.regularAppsUrls.count > 0 {
            regularAppsHintLabel.stringValue = "Drag apps and folders to reorder"
        } else {
            regularAppsHintLabel.stringValue = "Click + to add apps or folders"
        }

        // General
        itemSlotWidthCounterLabel.stringValue = "\(Int(userPrefsDataSource.itemSlotWidth.rounded()))"
        itemSlotWidthSlider.doubleValue = Double(userPrefsDataSource.itemSlotWidth)
        appIconSizeCounterLabel.stringValue = "\(Int(userPrefsDataSource.appIconSize.rounded()))"
        appIconSizeSlider.doubleValue = Double(userPrefsDataSource.appIconSize)
        updateGroupSpacingUi()
        hoverAnimationsButton.state = userPrefsDataSource.hoverAnimationsEnabled ? .on : .off
        groupBackgroundButton.state = userPrefsDataSource.groupBackgroundEnabled ? .on : .off
        maxRunningAppsCounterLabel.stringValue = "\(userPrefsDataSource.maxRunningApps)"
        maxRunningAppsSlider.integerValue = userPrefsDataSource.maxRunningApps

        switch userPrefsDataSource.sideToShowRunningApps {
        case .left:
            sideToShowRunningAppsControl.selectedSegment = 0
        case .right:
            sideToShowRunningAppsControl.selectedSegment = 1
        }

        duplicateAppsPriorityControl.isEnabled = userPrefsDataSource.hideDuplicateApps
        switch userPrefsDataSource.duplicateAppsPriority {
        case .runningApps:
            duplicateAppsPriorityControl.selectedSegment = 0
        case .regularApps:
            duplicateAppsPriorityControl.selectedSegment = 1
        }

        // Bottom
        appOpeningMethodPopUp.selectItem(withTitle: userPrefsDataSource.defaultAppOpeningMethod.rawValue.capitalizingFirstLetter())
		launchAtLoginButton.state = userPrefsDataSource.launchAtLogin ? .on : .off
	}

    func updateGroupSpacingUi() {
        guard isViewLoaded else { return }
        groupSpacingSlider.doubleValue = Double(userPrefsDataSource.groupSpacing)
        groupSpacingCounterLabel.stringValue = "\(Int(userPrefsDataSource.groupSpacing.rounded())) pt"
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
			sliderLabel: itemSlotWidthCounterLabel,
			sliderChanged: { (value) in
				self.delegate?.itemSlotWidthSliderDidChange(value)
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
			sliderLabel: maxRunningAppsCounterLabel,
			sliderEndedChanging: { value in
				self.delegate?.maxRunningAppsSliderDidChange(Int(value))

			}
		)
	}

	@IBAction func runningAppsSortingMethodChanged(_ sender: Any) {
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

    @IBAction func rightClickByDefaultPressed(_ sender: NSButton) {
        delegate?.rightClickByDefaultDidChange(sender.state == .on)
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
		delegate?.hideDuplicateAppsDidChange(sender.state == .on)
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
		sliderChanged?(slider.doubleValue)

		sliderLabel.stringValue = "\(slider.integerValue)"

        // Keyboard and accessibility actions also commit the value. During a
        // mouse drag, expensive list changes wait until the button is released.
        if event?.type != .leftMouseDown && event?.type != .leftMouseDragged {
			sliderEndedChanging?(slider.doubleValue)
		}
	}

	private func showFileExplorerToAddApps() {
		let dialog = NSOpenPanel()

		dialog.title = "Select apps or folders"
        dialog.message = "Choose applications or folders to pin in the menu bar."
		dialog.showsResizeIndicator = true
		dialog.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
		dialog.showsHiddenFiles = false
		dialog.allowsMultipleSelection = true
		dialog.canChooseDirectories = true
		dialog.canChooseFiles = true
		dialog.allowedFileTypes = ["app"]
        dialog.treatsFilePackagesAsDirectories = false
        dialog.canCreateDirectories = false

		if dialog.runModal() == NSApplication.ModalResponse.OK {
			delegate?.regularAppsUrlsWereAdded(dialog.urls)
			updateTable()
			updateUi()
		} else {
			// User clicked on "Cancel"
			return
		}
	}

    @IBAction func checkForUpdates(_ sender: NSButton) {
        delegate?.checkForUpdatesWasPressed(sender)
    }

	private func removeSelectedApps() {
		delegate?.regularAppsUrlsWereRemoved(regularAppsTable.selectedRowIndexes)
		updateTable()
		updateUi()
	}

	func updateTable() {
		regularAppsTable.reloadData()
	}

	@objc private func tableRowDoubleClicked() {
        guard userPrefsDataSource.regularAppsUrls.indices.contains(regularAppsTable.clickedRow) else { return }
		NSWorkspace.shared.activateFileViewerSelecting([userPrefsDataSource.regularAppsUrls[regularAppsTable.clickedRow]]) // reveal in finder
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
