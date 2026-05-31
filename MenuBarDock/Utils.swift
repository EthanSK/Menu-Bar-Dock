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

// Where to place elements that have NO known ordering info (their orderElement is
// not in the preferredOrder array). See `reorder(by:unorderedGoTo:)` for the full
// rationale — the goal is always "oldest / least-recent side, dropped first".
enum UnorderedPlacement {
	case start // beginning of the returned array
	case end   // end of the returned array
}

extension Array where Element: Reorderable {

	// Reorders elements to match `preferredOrder` (an array of ids ordered
	// least-recent -> most-recent for the running-apps case).
	//
	// ORDERING RULE FOR APPS WITH NO KNOWN ORDERING INFO (bug fix, voice 4442):
	// An element whose orderElement is NOT present in `preferredOrder` has no
	// known position. Previously such elements were returned as the LARGEST
	// (sorted to the END of the array). For `.mostRecentOnRight` + `suffix(limit)`
	// the end of the array is the MOST-RECENT / newest-app slot — so an
	// un-ordered app would steal the exact slot the freshly-launched app is
	// supposed to occupy, and `suffix` would even preferentially KEEP these
	// un-ordered apps while dropping genuinely-ordered ones. That defeats the
	// whole point of the recency ordering.
	//
	// NEW RULE: an element with no ordering info is treated as the OLDEST /
	// least-recent app, so it lands on the "end of the dock" side furthest from
	// where the newest app appears — and gets truncated FIRST by the limit
	// instead of stealing the newest-app slot or evicting a genuinely-ordered app.
	//
	// Which physical array end "oldest" maps to depends on the caller's truncation
	// direction, so the caller passes `unorderedGoTo`:
	//   - .start : un-ordered elements sort to the BEGINNING of the array.
	//              Use when the limit keeps the END (e.g. `suffix(limit)`, as with
	//              `.mostRecentOnRight` where the array is least->most recent).
	//   - .end   : un-ordered elements sort to the END of the array.
	//              Use when the limit keeps the FRONT (e.g. `prefix(limit)`, as with
	//              `.mostRecentOnLeft` where `preferredOrder` is reversed to
	//              most->least recent).
	// Either way the un-ordered app ends up on the least-recent side and is the
	// first to be dropped — never occupying the freshly-launched app's slot.
	func reorder(by preferredOrder: [Element.OrderElement], unorderedGoTo: UnorderedPlacement = .start) -> [Element] {
		sorted {
			let firstIdx = preferredOrder.firstIndex(of: $0.orderElement)
			let secondIdx = preferredOrder.firstIndex(of: $1.orderElement)

			switch (firstIdx, secondIdx) {
			case let (first?, second?):
				// Both have known positions: lower index comes first.
				return first < second
			case (nil, nil):
				// Neither has ordering info: treat as equal (stable, no reordering).
				return false
			case (nil, _):
				// $0 is un-ordered, $1 is ordered.
				// unorderedGoTo == .start -> un-ordered first  -> return true
				// unorderedGoTo == .end   -> un-ordered last   -> return false
				return unorderedGoTo == .start
			case (_, nil):
				// $0 is ordered, $1 is un-ordered (mirror of the case above).
				return unorderedGoTo != .start
			}
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
