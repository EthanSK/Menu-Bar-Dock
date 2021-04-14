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
		guard let bundle = Bundle(url: url) else { return nil }
		guard let name =
				bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String ??
				bundle.infoDictionary?[kCFBundleNameKey as String] as? String
		else { return nil }

		let icon = NSWorkspace.shared.icon(forFile: url.path)

		if tableColumn == tableView.tableColumns[0] {
			cellIdentifier = "AppCell"
		}

		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
			cell.textField?.stringValue = name
			cell.imageView?.image = icon
			return cell
		}
		return nil
	}
	
	//drag and drop copied from https://stackoverflow.com/questions/2121907/drag-drop-reorder-rows-on-nstableview

	func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
		let pasteboard = NSPasteboardItem()
		pasteboard.setString("\(row)", forType: .string)
		return pasteboard
	}

	func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
		return .move
	}

	func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {

		var oldIndexes = [Int]()
		 info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
			if let str = (dragItem.item as? NSPasteboardItem)?.string(forType: .string), let index = Int(str) {
				 oldIndexes.append(index)
			 }
		 }

		 var oldIndexOffset = 0
		 var newIndexOffset = 0

		 // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
		 // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
		 tableView.beginUpdates()
		 for oldIndex in oldIndexes {
			 if oldIndex < row {
				 tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
				 oldIndexOffset -= 1
			 } else {
				 tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
				 newIndexOffset += 1
			 }
		 }
		 tableView.endUpdates()

		 return true
	}
}
