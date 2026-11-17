//
//  AppsTablePreferencesViewController.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 14/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

extension PreferencesViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		userPrefsDataSource.regularAppsUrls.count
	}

}
extension PreferencesViewController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		return 30
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		var cellIdentifier: String = ""

		let url = userPrefsDataSource.regularAppsUrls[row]
		let bundle = Bundle(url: url)

		let icon = userPrefsDataSource.iconOverride(forAppAt: url) ?? NSWorkspace.shared.icon(forFile: url.path)

        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("AppActions") {
            let button = NSPopUpButton(frame: NSRect(x: 0, y: 2, width: 30, height: 26), pullsDown: true)
            button.isBordered = false
            button.menu?.autoenablesItems = false
            button.addItem(withTitle: "⋯")
            (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
            button.setAccessibilityLabel("Icon options for \(bundle?.name ?? url.deletingPathExtension().lastPathComponent)")
            button.toolTip = "Icon options"
            let configure = NSMenuItem(title: "Configure icon…", action: #selector(configureAppIcon), keyEquivalent: "")
            configure.target = self
            configure.representedObject = url // Bind to the app rather than a row index, which changes when the list is reordered.
            button.menu?.addItem(configure)
            let reset = NSMenuItem(title: "Reset icon", action: #selector(resetAppIcon), keyEquivalent: "")
            reset.target = self
            reset.representedObject = url
            reset.isEnabled = userPrefsDataSource.iconOverride(forAppAt: url) != nil
            button.menu?.addItem(reset)
            return button
        }

		if tableColumn == tableView.tableColumns[0] {
			cellIdentifier = "AppCell"
		}

		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
			cell.textField?.stringValue = bundle?.name ?? "NOT FOUND"
			cell.imageView?.image = icon
			return cell
		}
		return nil
	}

	// drag and drop copied from https://stackoverflow.com/questions/2121907/drag-drop-reorder-rows-on-nstableview

	func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
		let pasteboard = NSPasteboardItem()
		pasteboard.setString("\(row)", forType: .string)
		return pasteboard
	}

	func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
		guard info.draggingSource as? NSTableView === tableView,
		      (0...userPrefsDataSource.regularAppsUrls.count).contains(row) else { return [] }
		tableView.setDropRow(row, dropOperation: .above) // Pinned apps are inserted between rows.
		return .move
	}

	func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {

		let appCount = userPrefsDataSource.regularAppsUrls.count
		guard info.draggingSource as? NSTableView === tableView, dropOperation == .above,
		      (0...appCount).contains(row), let items = info.draggingPasteboard.pasteboardItems, !items.isEmpty else { return false }
		let rows = items.compactMap { $0.string(forType: .string).flatMap(Int.init) }
		guard rows.count == items.count, rows.allSatisfy({ (0..<appCount).contains($0) }) else { return false }
		let oldIndexes = IndexSet(rows)
		guard oldIndexes.count == rows.count else { return false }

		var oldIndexOffset = 0
		var newIndexOffset = 0

		tableView.beginUpdates()
 		for oldIndex in oldIndexes {
			if oldIndex < row {
				let old = oldIndex + oldIndexOffset
				let new = row - 1
				tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
				delegate?.regularAppUrlWasMoved(oldIndex: old, newIndex: new)
				oldIndexOffset -= 1
			} else {
				let old = oldIndex
				let new = row + newIndexOffset
				tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
				delegate?.regularAppUrlWasMoved(oldIndex: old, newIndex: new)
				newIndexOffset += 1
			}
		}
		tableView.endUpdates()
		return true
	}
}

extension PreferencesViewController {
    /// Previews an app icon before saving it to Menu Bar Dock's preferences.
    @objc private func configureAppIcon(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL, let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Configure icon"
        alert.informativeText = "\(Bundle(url: url)?.name ?? url.deletingPathExtension().lastPathComponent) — shown in Menu Bar Dock"
        let saveButton = alert.addButton(withTitle: "Save")
        saveButton.isEnabled = false
        alert.addButton(withTitle: "Cancel")
        let configurationView = AppIconConfigurationView(
            icon: userPrefsDataSource.iconOverride(forAppAt: url) ?? NSWorkspace.shared.icon(forFile: url.path),
            saveButton: saveButton
        )
        alert.accessoryView = configurationView
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn, let imageData = configurationView.selectedImageData {
                self.delegate?.appIconOverrideDidChange(imageData, forAppAt: url)
                self.updateTable()
            }
        }
    }

    /// Restores the app's original icon without changing any other preferences.
    @objc private func resetAppIcon(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        delegate?.appIconOverrideDidChange(nil, forAppAt: url)
        updateTable()
    }
}

private class AppIconConfigurationView: NSView {
    private(set) var selectedImageData: Data?
    private let imageView = NSImageView(frame: NSRect(x: 114, y: 48, width: 72, height: 72))
    private weak var saveButton: NSButton?

    /// Shows the current icon and lets the user choose its replacement.
    init(icon: NSImage, saveButton: NSButton) {
        self.saveButton = saveButton
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 132))
        imageView.image = icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setAccessibilityLabel("Icon preview")
        addSubview(imageView)
        let chooseButton = NSButton(title: "Choose image…", target: self, action: #selector(chooseImage))
        chooseButton.frame = NSRect(x: 80, y: 4, width: 140, height: 32)
        addSubview(chooseButton)
    }

    required init?(coder: NSCoder) {
        fatalError("AppIconConfigurationView is created programmatically")
    }

    /// Copies the chosen image so the override survives moving or deleting its source.
    @objc private func chooseImage(_ sender: NSButton) {
        guard let window = window else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose icon"
        panel.prompt = "Choose"
        panel.allowedFileTypes = NSImage.imageTypes + ["app"]
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            let image = url.pathExtension.lowercased() == "app" ? NSWorkspace.shared.icon(forFile: url.path) : NSImage(contentsOf: url)
            guard let image = image, let data = self.iconData(from: image) else { // A damaged or unsupported image must not replace an already-saved icon.
                let alert = NSAlert()
                alert.messageText = "Unable to load icon"
                alert.informativeText = "Choose another image."
                alert.beginSheetModal(for: window, completionHandler: nil)
                return
            }
            self.selectedImageData = data
            self.imageView.image = NSImage(data: data)
            self.saveButton?.isEnabled = true
        }
    }

    /// Makes a bounded PNG copy while preserving transparency and aspect ratio.
    private func iconData(from image: NSImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 256, height: 256).fill()
        let scale = min(256 / image.size.width, 256 / image.size.height) // Store only icon-sized pixels, not a potentially huge source photo in UserDefaults.
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (256 - size.width) / 2, y: (256 - size.height) / 2, width: size.width, height: size.height))
        return bitmap.representation(using: .png, properties: [:])
    }
}
