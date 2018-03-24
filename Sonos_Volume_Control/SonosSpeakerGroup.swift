//
//  SonosSpeakerGroup.swift
//  Menu Bar Controller for Sonos
//
//  Created by Alexander Heinrich on 24.03.18.
//  Copyright © 2018 Sn0wfreeze Development UG. All rights reserved.
//

import Cocoa
import SWXMLHash

struct SonosSpeakerGroup {
    let groupID: String
    var speakers: Set<SonosController> = Set()
    
    init(groupID: String) {
        self.groupID = groupID
    }
}
