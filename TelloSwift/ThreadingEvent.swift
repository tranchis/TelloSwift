//
//  ThreadingEvent.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 26/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

class ThreadingEvent {
    private var flag: Bool
    private let condition: NSCondition
    
    init() {
        self.flag = false
        condition = NSCondition()
    }
    
    func is_set() -> Bool {
        return self.flag
    }
    
    func set() {
        self.flag = true
        self.condition.broadcast()
    }
    
    func clear() {
        self.flag = false
    }
    
    func wait(timeout: Int?) -> Bool {
        if self.flag {
            return true
        } else {
            guard let to = timeout else {
                condition.wait()
                return true
            }
            return condition.wait(until: Date(timeIntervalSinceNow: TimeInterval(exactly: to)!))
        }
    }
    
    func wait() -> Bool {
        return self.wait(timeout: nil)
    }
}
