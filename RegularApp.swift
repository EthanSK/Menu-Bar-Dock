//
//  RegularApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 13/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class RegularApp {
   public var path: String
   public var bundle: Bundle
   public var icon: NSImage
   public var name: String

	var id: String {
		bundle.bundleURL.absoluteString
	}

   init(
	   path: String,
	   bundle: Bundle,
	   icon: NSImage,
	   name: String
   ) {
	   self.path = path
	   self.bundle = bundle
	   self.icon = icon
	   self.name = name
   }

}
