//
//  Notifications.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 04/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Foundation

extension Notification.Name {
	static let numberOfAppsSliderChanged = Notification.Name("numberOfAppsSliderChanged")
	static let numberOfAppsSliderEndedSliding = Notification.Name("numberOfAppsSliderEndedSliding")
	static let widthOfitemSliderChanged = Notification.Name("widthOfitemSliderChanged")
	static let widthOfitemSliderEndedSliding = Notification.Name("widthOfitemSliderEndedSliding")
	static let resetToDefaults = Notification.Name("resetToDefaults")
	static let sizeOfIconSliderChanged = Notification.Name("sizeOfIconSliderChanged")
	static let sizeOfIconSliderEndedSliding = Notification.Name("sizeOfIconSliderEndedSliding")
	static let sortingMethodChanged = Notification.Name("sortingMethodChanged")
	static let killLauncher = Notification.Name("killLauncher")


}
