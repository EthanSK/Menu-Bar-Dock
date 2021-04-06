//
//  ArrayExtensions.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Foundation

extension Collection where Element: Hashable {
	var unique: [Element] { //is ordered
		var set: Set<Element> = []
		return reduce(into: []) { set.insert($1).inserted ? $0.append($1) : () }
	}
}
