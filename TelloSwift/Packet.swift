//
//  Packet.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 26/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

class Packet {
    private var buf: [UInt8]
    
    init(cmd: [UInt8], pkt_type: UInt8) {
        self.buf = cmd
    }
    
    convenience init(bytes: [UInt8]) {
        self.init(cmd: bytes, pkt_type: 0x68)
    }
    
    convenience init(byte cmd: UInt8) {
        self.init(byte: cmd, pkt_type: 0x68)
    }
    
    convenience init(byte cmd: UInt8, pkt_type: UInt8) {
        self.init(cmd: [Protocol.START_OF_PACKET, 0, 0, 0, pkt_type, (cmd & 0xff), ((cmd >> 8) & 0xff), 0, 0], pkt_type: pkt_type)
    }
    
    func get_buffer() -> [UInt8] {
        return buf
    }
    
    func add_byte(short: UInt8) {
        self.buf.append(short & 0xff)
    }
    
    func add_byte(long: UInt16) {
        self.buf.append(UInt8(long & 0xff))
    }
    
    func add_time(time: Date) {
        let components = time.dateComponents()
        self.add_int16(value: components.hour!)
        self.add_int16(value: components.minute!)
        self.add_int16(value: components.second!)
        self.add_int16(value: (components.nanosecond!/1000000) & 0xff)
        self.add_int16(value: ((components.nanosecond!/1000000) >> 8) & 0xff)
    }
    
    private func add_int16(value: UInt16) {
        self.add_byte(long: value)
        self.add_byte(long: value >> 8)
    }
    
    private func add_int16(value: Int) {
        self.add_int16(value: UInt16(value))
    }
    
    func add_time() {
        self.add_time(time: Date())
    }
    
    func fixup(seq_num: UInt16) {
        var buf = self.get_buffer()
        if buf[0] == Protocol.START_OF_PACKET {
            let c = buf.count + 2
            let le = littleEndian16(num: UInt16(c))
            buf[1] = le.0
            buf[2] = le.1
            buf[1] = (buf[1] << 3)
            buf[3] = Crc.crc8(buf: Array(buf.prefix(upTo: 3)))
            let le2 = littleEndian16(num: seq_num)
            buf[7] = le2.0
            buf[8] = le2.1
            self.buf = buf
            self.add_int16(value: Crc.crc16(buf: buf))
        }
    }
    
    func littleEndian16(num: UInt16) -> (UInt8, UInt8) {
        return (UInt8(num & 0xff), UInt8(num >> 8 & 0xff))
    }
    
    func fixup() {
        self.fixup(seq_num: 0)
    }
}
