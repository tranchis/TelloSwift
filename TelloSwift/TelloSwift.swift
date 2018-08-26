//
//  TelloSwift.swift
//  TelloSwift
//
//  Created by Sergio Alletez-Napagao on 25/08/2018.
//  Copyright © 2018 Sergio Alletez-Napagao. All rights reserved.
//
import Foundation
import Socket

enum TelloError: Error {
    case timeout
}

extension Date {
    var millisecondsSince1970:Int {
        return Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
    
    func dateComponents() -> DateComponents {
        let calendar = Calendar.current
        let dc: Set<Calendar.Component> = [.hour, .minute, .second, .nanosecond]
        return calendar.dateComponents(dc, from: self)
    }
}

extension String
{
    func trim() -> String
    {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
    
    func data() -> [UInt8] {
        print("MY COUNT: ", self.count)
        print("YOUR COUNT: ", (Array(self.utf8)).count)
        return Array(self.utf8)
    }
}

//func byte_to_hexstring(str: String) -> String {
//    let pieces = str.data().map({ (c: UInt8) -> String in
//        String(format: "%02x ", c)
//    })
//    let joined = pieces.reduce("", { return $0 + $1 })
//    return joined.trim()
//}

func byte_to_hexstring(data: [UInt8]) -> String {
    let pieces = data.map({ (c: UInt8) -> String in
        String(format: "%02x ", c)
    })
    let joined = pieces.reduce("", { return $0 + $1 })
    return joined.trim()
}

public class TelloSwift : CustomStringConvertible {
    public var description: String {
        return "TelloSwift::object"
    }
    
    public let EVENT_FLIGHT_DATA = Event(name: "flight_data")

    public let EVENT_CONNECTED = Event(name: "connected")
    private let EVENT_WIFI = Event(name: "wifi")
    private let EVENT_LIGHT = Event(name: "light")
    private let EVENT_LOG = Event(name: "log")
    private let EVENT_TIME = Event(name: "time")
    private let EVENT_VIDEO_FRAME = Event(name: "video frame")
    public let EVENT_VIDEO_DATA = Event(name: "video data")
    public let EVENT_DISCONNECTED = Event(name: "disconnected")
    private let __EVENT_CONN_REQ = Event(name: "conn_req")
    private let __EVENT_CONN_ACK = Event(name: "conn_ack")
    private let __EVENT_TIMEOUT = Event(name: "timeout")
    private let __EVENT_QUIT_REQ = Event(name: "quit_req")
    
    private let STATE_DISCONNECTED = State(name: "disconnected")
    private let STATE_CONNECTING = State(name: "connecting")
    private let STATE_CONNECTED = State(name: "connected")
    private let STATE_QUIT = State(name: "quit")

    private let tello_addr: Socket.Address
    private let debug: Bool
    private let pkt_seq_num, port, udpsize: Int
    private let sock: Socket
    private let lock: NSRecursiveLock
    public let log: Logger
    private let exposure, video_encoder_rate: UInt8
    private var video_stream: VideoStream?

    private var left_x, left_y, right_x, right_y: Double
    private var video_enabled: Bool
    private var state: State
    private var connected: ThreadingEvent
    private var video_data_loss: Int32
    private var prev_video_data_time: Date?
    private var video_data_size: Int

    public init(port: Int) {
        self.tello_addr = Socket.createAddress(for: "192.168.10.1", on: 8889)!
        self.debug = false
        self.pkt_seq_num = 0x01e4
        self.port = port
        self.udpsize = 2000
        self.left_x = 0.0
        self.left_y = 0.0
        self.right_x = 0.0
        self.right_y = 0.0
        self.state = self.STATE_DISCONNECTED
        self.lock = NSRecursiveLock()
        self.connected = ThreadingEvent()
        self.video_enabled = false
        self.prev_video_data_time = nil
        self.video_data_size = 0
        self.video_data_loss = 0
        self.log = Logger(header: "Tello")
        self.exposure = 0
        self.video_encoder_rate = 4
        self.video_stream = nil
        
        self.sock = try! Socket.create(family: .inet, type: .datagram, proto: .udp)
        try! self.sock.setReadTimeout(value: 10)
        try! self.sock.setWriteTimeout(value: 10)
        
        Dispatcher.connect(receiver: state_machine, sig: Signal.All)
        DispatchQueue.init(label: "recv_thread").async {
            self.recv_thread()
        }
        DispatchQueue.init(label: "video_thread").async {
            self.video_thread()
        }
    }
    
    public convenience init() {
        self.init(port: 9000)
    }
    
    private func state_machine(event: Event, sender: CustomStringConvertible, args: Arguments) {
        self.lock.lock()
        let cur_state = self.state
        var event_connected = false
        var event_disconnected = false
        log.debug(str: String(format: "event %@ in state %@", event.description, self.state.description))
        
        if self.state == self.STATE_DISCONNECTED {
            if event == self.__EVENT_CONN_REQ {
                self.send_conn_req()
                self.state = self.STATE_CONNECTING
            } else if event == self.__EVENT_QUIT_REQ {
                self.state = self.STATE_QUIT
                event_disconnected = true
                self.video_enabled = false
            }
        } else if self.state == self.STATE_CONNECTING {
            if event == self.__EVENT_CONN_ACK {
                self.state = self.STATE_CONNECTED
                event_connected = true
                self.send_time_command()
            } else if event == self.__EVENT_TIMEOUT {
                self.send_conn_req()
            } else if event == self.__EVENT_QUIT_REQ {
                self.state = self.STATE_QUIT
            }
        } else if self.state == self.STATE_CONNECTED {
            if event == self.__EVENT_TIMEOUT {
                self.send_conn_req()
                self.state = self.STATE_CONNECTING
                event_disconnected = true
                self.video_enabled = false
            } else if event == self.__EVENT_QUIT_REQ {
                self.state = self.STATE_QUIT
                event_disconnected = true
                self.video_enabled = false
            }
        } else if self.state == self.STATE_QUIT {
            
        }
        
        if cur_state != self.state {
            log.info(str: String(format: "state transit %@ -> %@", cur_state.description, self.state.description))
        }
        self.lock.unlock()
        
        if event_connected {
            self.publish(event: self.EVENT_CONNECTED, args: args)
            self.connected.set()
        }
        if event_disconnected {
            self.publish(event: self.EVENT_DISCONNECTED, args: args)
            self.connected.clear()
        }
    }
    
    private func recv_thread() {
        while self.state != self.STATE_QUIT {
            if self.state == self.STATE_CONNECTED {
                self.send_stick_command()
            }
            
            var data: Data = Data(capacity: self.udpsize)
            do {
                let output = try self.sock.listen(forMessage: &data, on: self.port)
                if output.bytesRead > 0 {
                    let bytes = [UInt8](data)
                    log.debug(str: String(format: "recv(%d): %@", bytes.count, byte_to_hexstring(data: bytes)))
                    self.process_packet(data: bytes)
                }
            } catch let error {
                guard let socketError = error as? Socket.Error else {
                    log.error(str: "Unexpected error...")
                    return
                }
                
                if socketError.errorCode == Socket.SOCKET_ERR_CONNECT_TIMEOUT {
                    if self.state == self.STATE_CONNECTED {
                        log.error(str: "recv: timeout")
                    }
                    self.publish(event: self.__EVENT_TIMEOUT)
                } else {
                    log.error(str: String(format: "recv: %@", error.localizedDescription))
                }
            }
        }
        
        log.info(str: "exit from the recv thread.")
    }
    
    private func video_thread() {
        log.info(str: "start video thread")
        
        let sock = try! Socket.create(family: .inet, type: .datagram, proto: .udp)
        let port = 6038
        try! sock.setReadTimeout(value: 5)
        try! sock.setWriteTimeout(value: 5)
        sock.readBufferSize = 512 * 1024
      
        log.info(str: String(format: "video receive buffer size = %d", sock.readBufferSize))
        
        var prev_header: UInt8? = nil
        var prev_ts: Date? = nil
        var history: [(Date, Int, Int)] = []

        while self.state != self.STATE_QUIT {
            if !self.video_enabled {
                sleep(1)
            } else {
                var data: Data = Data(capacity: self.udpsize)
                do {
                    let info = try self.sock.listen(forMessage: &data, on: port)
                    if info.bytesRead > 0 {
                        let bytes = [UInt8](data)
                        let now = Date()
                        let prefix: [UInt8] = Array(bytes.prefix(2))
                        log.debug(str: String(format: "video recv: %@ %d bytes (%d)", byte_to_hexstring(data: prefix), bytes.count, info.bytesRead))
                        let show_history = false
                        
                        let header = bytes[0]
                        if prev_header != nil
                            && header != prev_header
                            && header != ((prev_header! + 1) & 0xff) {
                            var loss: Int32 = Int32(header) - Int32(prev_header!)
                            if loss < 0 {
                                loss = loss + 256
                            }
                            self.video_data_loss = self.video_data_loss + Int32(loss)
                        }
                        prev_header = header
                        
                        if prev_ts != nil
                            && 100 < (now.millisecondsSince1970 - prev_ts!.millisecondsSince1970) {
                            log.info(str: String(format: "video recv: %d bytes %02x%02x +%03d",
                                                 bytes.count, bytes[0], bytes[1],
                                                 now.millisecondsSince1970 - prev_ts!.millisecondsSince1970))
                        }
                        prev_ts = now
                        
                        history.append((now, bytes.count, 256 * Int(bytes[0]) + Int(bytes[1])))
                        if 100 < history.count {
                            history = Array(history.dropFirst())
                        }
                        
                        if show_history {
                            prev_ts = history[0].0
                            for i in 0..<history.count {
                                let ar = history[i]
                                let ts = ar.0
                                let sz = ar.1
                                let sn = ar.2
                                let components = ts.dateComponents()
                                
                                print(String(format: "    %02d:%02d:%02d.%03d %4d bytes %04x +%03d%@", components.hour!, components.minute!, components.second!, components.nanosecond!/1000000, sz, sn, (ts.millisecondsSince1970 - prev_ts!.millisecondsSince1970), (i == history.count - 1) ? " *" : ""))
                                prev_ts = ts
                            }
                            if history.count > 0 {
                                history = [history.last!]
                            } else {
                                history = []
                            }
                        }
                        
                        self.publish(event: self.EVENT_VIDEO_FRAME, data: Array(bytes.dropFirst(2)))
                        self.publish(event: self.EVENT_VIDEO_DATA, data: bytes)
                        
                        if self.prev_video_data_time == nil {
                            self.prev_video_data_time = now
                        }
                        self.video_data_size = self.video_data_size + bytes.count
                        let dur = (now.millisecondsSince1970 - self.prev_video_data_time!.millisecondsSince1970)
                        
                        if 2000 < dur {
                            log.info(str: String(format: "video data %d bytes %5.1fKB/sec", self.video_data_size, String(self.video_data_size / dur / 1024) + String(self.video_data_loss == 0 ? "" : String(format: " loss=%d", self.video_data_loss))))
                            self.video_data_size = 0
                            self.prev_video_data_time = now
                            self.video_data_loss = 0
                            
                            self.send_start_video()
                        }
                    }
                } catch let error {
                    guard let socketError = error as? Socket.Error else {
                        log.error(str: "Unexpected error...")
                        return
                    }
                    
                    if socketError.errorCode == Socket.SOCKET_ERR_CONNECT_TIMEOUT {
                        if self.state == self.STATE_CONNECTED {
                            log.error(str: "video recv: timeout")
                        }
                        self.publish(event: self.__EVENT_TIMEOUT)
                    } else {
                        log.error(str: String(format: "video recv: %@", error.localizedDescription))
                    }
                }
            }
        }
        
        log.info(str: "exit from the video thread.")
    }
    
    private func send_conn_req() -> Bool {
        let port = 9617
        let port0 = (Int(port/1000) % 10) << 4 | (Int(port/100) % 10)
        let port1 = (Int(port/10) % 10) << 4 | (Int(port/1) % 10)
//        let buf = String(format: "conn_req:%c%c", port0, port1)
        var buf: [UInt8] = [0x63, 0x6f, 0x6e, 0x6e, 0x5f, 0x72, 0x65, 0x71, 0x3a]
        buf.append(UInt8(port0))
        buf.append(UInt8(port1))
        
        log.info(str: String(format: "send connection request (cmd=\"%@%02x%02x\")", String(bytes: Array(buf.dropLast(2)), encoding: .utf8)!, port0, port1))
        return self.send_packet(pkt: Packet(bytes: buf))
    }
    
    private func send_packet(pkt: Packet) -> Bool {
        do {
            let cmd = pkt.get_buffer()
            let data = Data(cmd)
            try self.sock.write(from: data, to: self.tello_addr)
            log.debug(str: String(format: "send_packet: %@", byte_to_hexstring(data: cmd)))
            return true
        } catch let error {
            guard let socketError = error as? Socket.Error else {
                log.error(str: "Unexpected error...")
                return false
            }
            
            if self.state == self.STATE_CONNECTED {
                log.error(str: String(format: "send_packet: %@", socketError.description))
            }
            else {
                log.info(str: String(format: "send_packet: %@", socketError.description))
            }
            return false
        }
    }
    
    private func send_time_command() -> Bool {
        log.info(str: String(format: "send_time (cmd=0x%02x seq=0x%04x)", Protocol.TIME_CMD, self.pkt_seq_num))
        let pkt = Packet(byte: Protocol.TIME_CMD, pkt_type: 0x50)
        pkt.add_byte(short: 0)
        pkt.add_time()
        pkt.fixup()
        return self.send_packet(pkt: pkt)
    }
    
    private func publish(event: Event, data: [UInt8]?, args: Arguments) {
        log.debug(str: String(format: "publish signal=%@, data=%@", event.description, data ?? "NULL"))
        var updatedArguments = args
        updatedArguments.data = data
        updatedArguments.signal = nil
        updatedArguments.sender = nil
        Dispatcher.send(event: event, sender: self, args: updatedArguments)

    }
    
    private func publish(event: Event) {
        publish(event: event, data: nil, args: Arguments())
    }
    
    private func publish(event: Event, args: Arguments) {
        publish(event: event, data: nil, args: args)
    }
    
    private func publish(event: Event, data: [UInt8]) {
        publish(event: event, data: data, args: Arguments())
    }
    
    private func send_stick_command() -> Bool {
        let pkt = Packet(byte: Protocol.STICK_CMD, pkt_type: 0x60)
        
        let axis1 = Int(1024 + 660.0 * self.right_x) & 0x7ff
        let axis2 = Int(1024 + 660.0 * self.right_y) & 0x7ff
        let axis3 = Int(1024 + 660.0 * self.left_y) & 0x7ff
        let axis4 = Int(1024 + 660.0 * self.left_x) & 0x7ff

        log.debug(str: String(format: "stick command: yaw=%4d thr=%4d pit=%4d rol=%4d", axis4, axis3, axis2, axis1))
        log.debug(str: String(format: "stick command: yaw=%04x thr=%04x pit=%04x rol=%04x", axis4, axis3, axis2, axis1))
        pkt.add_byte(short: UInt8(((axis2 << 11 | axis1) >> 0) & 0xff))
        pkt.add_byte(short: UInt8(((axis2 << 11 | axis1) >> 8) & 0xff))
        pkt.add_byte(short: UInt8(((axis3 << 11 | axis2) >> 5) & 0xff))
        pkt.add_byte(short: UInt8(((axis4 << 11 | axis3) >> 2) & 0xff))
        pkt.add_byte(short: UInt8(((axis4 << 11 | axis3) >> 10) & 0xff))
        pkt.add_byte(short: UInt8(((axis4 << 11 | axis3) >> 18) & 0xff))
        pkt.add_time()
        pkt.fixup()
        log.debug(str: String(format: "stick command: %@", byte_to_hexstring(data: pkt.get_buffer())))
        return self.send_packet(pkt: pkt)
    }
    
    private func process_packet(data: [UInt8]) -> Bool {
        if String(bytes: Array(data.prefix(upTo: 9)), encoding: .utf8) == "conn_ack:" {
            log.info(str: String(format: "connected. (port=%2x%2x)", data[9], data[10])) // REFINE
            log.debug(str: String(format: "    %@", byte_to_hexstring(data: data)))
            if self.video_enabled {
                self.send_exposure()
                self.send_video_encoder_rate()
                self.send_start_video()
            }
            self.publish(event: __EVENT_CONN_ACK, data: data)
            return true
        }
        
        if data[0] != Protocol.START_OF_PACKET {
            log.info(str: String(format: "start of packet != %02x (%02x) (ignored)", Protocol.START_OF_PACKET, data[0]))
            log.info(str: String(format: "    %@", byte_to_hexstring(data: data)))
            log.info(str: String(format: "    %@", String(bytes: data, encoding: .utf8) ?? "Could not parse"))
            return false
        }
        
        let pkt = Packet(bytes: data)
        let cmd = int16(data[5], data[6])
//        log.info(str: String(format: "cmd: %d", cmd))
        if cmd == Protocol.LOG_MSG {
            log.debug(str: String(format: "recv: log: %@", byte_to_hexstring(data: Array(data.dropFirst(9)))))
            self.publish(event: self.EVENT_LOG, data: Array(data.dropFirst(9)))
        } else if cmd == Protocol.WIFI_MSG {
            log.debug(str: String(format: "recv: wifi: %@", byte_to_hexstring(data: Array(data.dropFirst(9)))))
            self.publish(event: self.EVENT_WIFI, data: Array(data.dropFirst(9)))
        } else if cmd == Protocol.LIGHT_MSG {
            log.debug(str: String(format: "recv: light: %@", byte_to_hexstring(data: Array(data.dropFirst(9)))))
            self.publish(event: self.EVENT_LIGHT, data: Array(data.dropFirst(9)))
        } else if cmd == Protocol.FLIGHT_MSG {
            let flight_data = FlightData(data: Array(data.dropFirst(9)))
            log.debug(str: String(format: "recv: flight data: %@", flight_data.description))
            self.publish(event: self.EVENT_FLIGHT_DATA, data: Array(flight_data.description.utf8))
        } else if cmd == Protocol.TIME_CMD {
            log.debug(str: String(format: "recv: time data: %@", byte_to_hexstring(data: data)))
            self.publish(event: self.EVENT_TIME, data: Array(Array(data.dropFirst(7)).prefix(upTo: 2)))
        } else if cmd == Protocol.TAKEOFF_CMD || cmd == Protocol.LAND_CMD || cmd == Protocol.VIDEO_START_CMD || cmd == Protocol.VIDEO_ENCODER_RATE_CMD {
            log.info(str: String(format: "recv: ack: cmd=0x%02x seq=0x%04x %@", int16(data[5], data[6]), int16(data[7], data[8]), byte_to_hexstring(data: data)))
        } else {
            log.info(str: String(format: "unknown packet: %@", byte_to_hexstring(data: data)))
            return false
        }
        return true
    }
    
    private func send_exposure() -> Bool {
        let pkt = Packet(byte: Protocol.EXPOSURE_CMD, pkt_type: 0x48)
        pkt.add_byte(short: self.exposure)
        pkt.fixup()
        return self.send_packet(pkt: pkt)
    }
    
    private func send_video_encoder_rate() -> Bool {
        let pkt = Packet(byte: Protocol.VIDEO_ENCODER_RATE_CMD, pkt_type: 0x68)
        pkt.add_byte(short: self.video_encoder_rate)
        pkt.fixup()
        return self.send_packet(pkt: pkt)
    }
    
    private func process_packet(str: String) {
        self.process_packet(data: str.data())
    }
    
    private func send_start_video() -> Bool {
        let pkt = Packet(byte: Protocol.VIDEO_START_CMD, pkt_type: 0x60)
        pkt.fixup()
        return self.send_packet(pkt: pkt)
    }
    
    public func subscribe(signal: Event, handler: @escaping (Event, CustomStringConvertible, Arguments) -> ()) {
        Dispatcher.connect(receiver: handler, sig: signal)
    }
    
    public func connect() {
        self.publish(event: self.__EVENT_CONN_REQ)
    }
    
    public func wait_for_connection(timeout: Int?) throws {
        if !self.connected.wait(timeout: timeout) {
            throw TelloError.timeout
        }
    }
    
    public func wait_for_connection() throws {
        try self.wait_for_connection(timeout: nil)
    }
    
    public func takeoff() -> Bool {
        log.info(str: String(format: "takeoff (cmd=0x%02x seq=0x%04x)", Protocol.TAKEOFF_CMD, self.pkt_seq_num))
        let pkt = Packet(byte: UInt8(Protocol.TAKEOFF_CMD))
        pkt.fixup()
        return self.send_packet(pkt: pkt)
    }
    
    public func down(value: UInt8) {
        log.info(str: String(format: "down(val=%d)", value))
        self.left_y = Double(value) / 100.0 * -1
    }
    
    public func land() -> Bool {
        log.info(str: String(format: "land (cmd=0x%02x seq=0x%04x)", Protocol.LAND_CMD, self.pkt_seq_num))
        let pkt = Packet(byte: UInt8(Protocol.LAND_CMD))
        pkt.add_byte(short: 0x00)
        pkt.fixup()
        return self.send_packet(pkt: pkt)
    }
    
    public func quit() {
        log.info(str: "quit")
        self.publish(event: self.__EVENT_QUIT_REQ)
    }
    
    public func get_video_stream() -> VideoStream {
        var newly_created = false
        self.lock.lock()
        log.info(str: "get video stream")
        if self.video_stream == nil {
            self.video_stream = VideoStream(drone: self)
            self.video_stream!.initializeSubscriptions()
            newly_created = true
        }
        let res = self.video_stream!
        self.lock.unlock()
        if newly_created {
            self.send_exposure()
            self.send_video_encoder_rate()
            self.start_video()
        }
        return res
    }
    
    private func start_video() -> Bool {
        log.info(str: String(format: "start video (cmd=0x%02x seq=0x%04x)", Protocol.VIDEO_START_CMD, self.pkt_seq_num))
        self.video_enabled = true
        self.send_exposure()
        self.send_video_encoder_rate()
        return self.send_start_video()
    }
}
