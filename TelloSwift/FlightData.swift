//
//  FlightData.swift
//  TelloSwift
//
//  Created by Sergio Alvarez-Napagao on 26/08/2018.
//  Copyright © 2018 Sergio Alvarez-Napagao. All rights reserved.
//

import Foundation

func int16(_ b1: UInt8, _ b2: UInt8) -> UInt16 {
    return UInt16(b2) * 256 + UInt16(b1)
}

class FlightData : CustomStringConvertible {
    var description: String {
        return String(format: "height=%2d, fly_mode=0x%02x, battery_percentage=%2d, drone_battery_left=0x%04x", self.height, self.fly_mode, self.battery_percentage, self.drone_battery_left)
    }
    
    var battery_low: Int
    var battery_lower: Int
    var battery_percentage: Int
    var battery_state: Int
    var camera_state: Int
    var down_visual_state: Int
    var drone_battery_left: Int
    var drone_fly_time_left: Int
    var drone_hover: Int
    var em_open: Int
    var em_sky: Int
    var em_ground: Int
    var east_speed: Int
    var electrical_machinery_state: Int
    var factory_mode: Int
    var fly_mode: Int
    var fly_speed: Int
    var fly_time: Int
    var front_in: Int
    var front_lsc: Int
    var front_out: Int
    var gravity_state: Int
    var ground_speed: Int
    var height: Int
    var imu_calibration_state: Int
    var imu_state: Int
    var light_strength: Int
    var north_speed: Int
    var outage_recording: Int
    var power_state: Int
    var pressure_state: Int
    var smart_video_exit_mode: Int
    var temperature_height: Int
    var throw_fly_timer: Int
    var wifi_disturb: Int
    var wifi_strength: Int
    var wind_state: Int

    init(data: [UInt8]) {
        self.battery_low = 0
        self.battery_lower = 0
        self.battery_percentage = 0
        self.battery_state = 0
        self.camera_state = 0
        self.down_visual_state = 0
        self.drone_battery_left = 0
        self.drone_fly_time_left = 0
        self.drone_hover = 0
        self.em_open = 0
        self.em_sky = 0
        self.em_ground = 0
        self.east_speed = 0
        self.electrical_machinery_state = 0
        self.factory_mode = 0
        self.fly_mode = 0
        self.fly_speed = 0
        self.fly_time = 0
        self.front_in = 0
        self.front_lsc = 0
        self.front_out = 0
        self.gravity_state = 0
        self.ground_speed = 0
        self.height = 0
        self.imu_calibration_state = 0
        self.imu_state = 0
        self.light_strength = 0
        self.north_speed = 0
        self.outage_recording = 0
        self.power_state = 0
        self.pressure_state = 0
        self.smart_video_exit_mode = 0
        self.temperature_height = 0
        self.throw_fly_timer = 0
        self.wifi_disturb = 0
        self.wifi_strength = 0
        self.wind_state = 0
        
        if data.count >= 24 {
            self.height = Int(int16(data[0], data[1]))
            self.north_speed = Int(int16(data[2], data[3]))
            self.east_speed = Int(int16(data[4], data[5]))
            self.ground_speed = Int(int16(data[6], data[7]))
            self.fly_time = Int(int16(data[8], data[9]))
            
            self.imu_state = Int(((data[10] >> 0) & 0x1))
            self.pressure_state = Int(((data[10] >> 1) & 0x1))
            self.down_visual_state = Int(((data[10] >> 2) & 0x1))
            self.power_state = Int(((data[10] >> 3) & 0x1))
            self.battery_state = Int(((data[10] >> 4) & 0x1))
            self.gravity_state = Int(((data[10] >> 5) & 0x1))
            self.wind_state = Int(((data[10] >> 7) & 0x1))
            
            self.imu_calibration_state = Int(data[11])
            self.battery_percentage = Int(data[12])
            self.drone_battery_left = Int(int16(data[13], data[14]))
            self.drone_fly_time_left = Int(int16(data[15], data[16]))
            
            self.em_sky = Int(((data[17] >> 0) & 0x1))
            self.em_ground = Int(((data[17] >> 1) & 0x1))
            self.em_open = Int(((data[17] >> 2) & 0x1))
            self.drone_hover = Int(((data[17] >> 3) & 0x1))
            self.outage_recording = Int(((data[17] >> 4) & 0x1))
            self.battery_low = Int(((data[17] >> 5) & 0x1))
            self.battery_lower = Int(((data[17] >> 6) & 0x1))
            self.factory_mode = Int(((data[17] >> 7) & 0x1))
            
            self.fly_mode = Int(data[18])
            self.throw_fly_timer = Int(data[19])
            self.camera_state = Int(data[20])
            self.electrical_machinery_state = Int(data[21])
            
            self.front_in = Int(((data[22] >> 0) & 0x1))
            self.front_out = Int(((data[22] >> 1) & 0x1))
            self.front_lsc = Int(((data[22] >> 2) & 0x1))
            
            self.temperature_height = Int(((data[23] >> 0) & 0x1))
        }
    }
}
