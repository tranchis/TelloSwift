//
//  VideoStream.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 26/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation
import AVFoundation

public class VideoStream : AVAsset {
    private let drone: TelloSwift
    private let log: Logger
    private let cond: NSCondition
    private var queue: [[UInt8]]
    private var closed: Bool
    
    init(drone: TelloSwift) {
        self.drone = drone
        self.log = drone.log
        self.cond = NSCondition()
        self.queue = []
        self.closed = false
    }
    
    func initializeSubscriptions() {
        self.drone.subscribe(signal: drone.EVENT_CONNECTED, handler: handleEvent)
        self.drone.subscribe(signal: drone.EVENT_DISCONNECTED, handler: handleEvent)
        self.drone.subscribe(signal: drone.EVENT_VIDEO_DATA, handler: handleEvent)
    }
    
    func handleEvent(event: Event, sender: CustomStringConvertible, args: Arguments) {
        if event == self.drone.EVENT_CONNECTED {
            self.log.info(str: String(format: "%@.handle_event(CONNECTED)", String(describing: self)))
        } else if event == self.drone.EVENT_DISCONNECTED {
            self.log.info(str: String(format: "%@.handle_event(DISCONNECTED)", String(describing: self)))
            self.cond.lock()
            self.queue = []
            self.closed = true
            self.cond.broadcast()
            self.cond.unlock()
        } else if event == self.drone.EVENT_VIDEO_DATA {
            let data = args.data!
            self.log.debug(str: String(format: "%@.handle_event(VIDEO_DATA, size=%d)", String(describing: self), data.count))
            self.cond.lock()
            self.queue.append(Array(data.dropFirst(2)))
            self.cond.broadcast()
            self.cond.unlock()
        }
    }
}
