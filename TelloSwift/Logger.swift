//
//  Logger.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 25/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

public class Logger {
    let LOG_ERROR = 0
    let LOG_WARN = 1
    let LOG_INFO = 2
    let LOG_DEBUG = 3
    let LOG_ALL = 99
    
    var log_level: Int
    let header_string: String
    let lock: NSRecursiveLock
    
    init(header: String) {
        self.log_level = LOG_INFO
        self.header_string = header
        self.lock = NSRecursiveLock()
    }
    
    func header() -> String {
        let now = Date()
        
        let components = now.dateComponents()
        let ts = String(format: "%02d:%02d:%02d.%03d", components.hour!, components.minute!, components.second!, components.nanosecond!/1000000)
        
        return String(format: "%@: %@", self.header_string, ts)
    }
    
    func set_level(level: Int) {
        self.log_level = level
    }
    
    func output(msg: String) {
        self.lock.lock()
        print(msg)
        self.lock.unlock()
    }
    
    func error(str: String) {
        if self.log_level < LOG_ERROR {
            return
        }
        self.output(msg: String(format: "%@: Error: %@", self.header(), str))
    }
    
    func warn(str: String) {
        if self.log_level < LOG_WARN {
            return
        }
        self.output(msg: String(format: "%@: Warn: %@", self.header(), str))
    }
    
    func info(str: String) {
        if self.log_level < LOG_INFO {
            return
        }
        self.output(msg: String(format: "%@: Info: %@", self.header(), str))
    }
    
    func debug(str: String) {
        if self.log_level < LOG_DEBUG {
            return
        }
        self.output(msg: String(format: "%@: Debug: %@", self.header(), str))
    }
}
