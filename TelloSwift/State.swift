//
//  State.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 25/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

class State : Equatable, CustomStringConvertible {
    var description: String {
        return String(format: "%@::%@", String(describing: type(of: self)), self.name)
    }
    
    static func == (lhs: State, rhs: State) -> Bool {
        return lhs.name == rhs.name
    }
    
    private let name: String
    
    init(name: String) {
        self.name = name
    }
    
    init() {
        self.name = "anonymous"
    }
}
