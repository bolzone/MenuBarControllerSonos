//
//  AppUtil.swift
//  Sonos_Volume_Control
//
//  Created by Alexander Heinrich on 13.04.18.
//  Copyright © 2018 Sn0wfreeze Development UG. All rights reserved.
//

import Foundation

internal func dPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
        print(items, separator: separator, terminator: terminator)
    #endif
}
