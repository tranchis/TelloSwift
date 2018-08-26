//
//  Dispatcher.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 25/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

public class Signal {
    public static let All = Event(name: "*")
}

class Dispatcher {
    private static var signals: [Event:[(Event, CustomStringConvertible, Arguments) -> ()]] = [:]
    
    static func connect(receiver: @escaping (Event, CustomStringConvertible, Arguments) -> (), sig: Event) {
        guard let potential_signals = signals[sig] else {
            signals[sig] = [receiver]
            return
        }
        signals[sig]?.append(receiver)
    }
    
    static func connect(receiver: @escaping (Event, CustomStringConvertible, Arguments) -> ()) {
        connect(receiver: receiver, sig: Signal.All)
    }
    
    static func send(event: Event, sender: CustomStringConvertible, args: Arguments) {
        var receivers: [(Event, CustomStringConvertible, Arguments) -> ()] = []
        if signals.keys.contains(event) {
            receivers = (signals[event] ?? []) + (signals[Signal.All] ?? [])
        } else {
            receivers = signals[Signal.All] ?? []
        }
        for receiver in receivers {
            receiver(event, sender, args)
        }
    }
}


