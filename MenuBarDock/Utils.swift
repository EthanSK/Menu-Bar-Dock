//
//  Utils.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Foundation

protocol Reorderable {
	associatedtype OrderElement: Equatable
	var orderElement: OrderElement { get }
}

extension Array where Element: Reorderable {

	func reorder(by preferredOrder: [Element.OrderElement]) -> [Element] {
		sorted {
			guard let first = preferredOrder.firstIndex(of: $0.orderElement) else {
				return false
			}

			guard let second = preferredOrder.firstIndex(of: $1.orderElement) else {
				return true
			}

			return first < second
		}
	}
}

extension Array {
	mutating func remove(at set: IndexSet) {
		var arr = Swift.Array(self.enumerated())
		arr.removeAll {set.contains($0.offset)}
		self = arr.map {$0.element}
	}
}

extension String {
	func capitalizingFirstLetter() -> String {
		return prefix(1).capitalized + dropFirst()
	}

	mutating func capitalizeFirstLetter() {
		self = self.capitalizingFirstLetter()
	}
}

extension Bundle {
	var name: String {
		self.localizedInfoDictionary?[kCFBundleNameKey as String] as? String ??
		self.infoDictionary?[kCFBundleNameKey as String] as? String ??
		self.bundleURL.lastPathComponent.components(separatedBy: ".")[0]
	}
}
