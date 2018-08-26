//
//  Protocol.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 26/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

class Protocol {
    static let START_OF_PACKET: UInt8 = 0xcc
    static let WIFI_MSG: UInt8 = 0x1a
    static let VIDEO_RATE_QUERY: UInt8 = 40
    static let LIGHT_MSG: UInt8 = 53
    static let FLIGHT_MSG: UInt8 = 0x56
    static let LOG_MSG: UInt16 = 0x1050
    
    static let VIDEO_ENCODER_RATE_CMD: UInt8 = 0x20
    static let VIDEO_START_CMD: UInt8 = 0x25
    static let EXPOSURE_CMD: UInt8 = 0x34
    static let TIME_CMD: UInt8 = 70
    static let STICK_CMD: UInt8 = 80
    static let TAKEOFF_CMD: UInt16 = 0x0054
    static let LAND_CMD: UInt16 = 0x0055
    static let FLIP_CMD: UInt16 = 0x005c
    
    static let FlipFront = 0
    static let FlipLeft = 1
    static let FlipBack = 2
    static let FlipRight = 3
    static let FlipForwardLeft = 4
    static let FlipBackLeft = 5
    static let FlipBackRight = 6
    static let FlipForwardRight = 7
}
