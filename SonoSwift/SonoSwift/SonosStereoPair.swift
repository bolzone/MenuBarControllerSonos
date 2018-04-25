//
//  SonosStereoPair.swift
//  Menu Bar Controller for Sonos
//
//  Created by Alexander Heinrich on 08.04.18.
//  Copyright © 2018 Sn0wfreeze Development UG. All rights reserved.
//

import Cocoa

public struct SonosStereoPair: Hashable {
    public let controller: SonosDevice
    public let otherSpeaker: SonosDevice
    
    public init?(s1: SonosDevice, s2: SonosDevice) {
        guard s1.roomName == s2.roomName && s1 != s2 else {return nil}
        
        if s1.groupState.groupID.isEmpty == false {
            controller = s1
            otherSpeaker = s2
        }else if s2.groupState.groupID.isEmpty == false {
            controller = s2
            otherSpeaker = s1
        }else {
            return nil
        }
    }
    
    public var hashValue: Int {
        return controller.deviceInfo?.zoneName.hashValue ?? controller.roomName.hashValue
    }
}
