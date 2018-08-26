import TelloSwiftFramework

func handler(event: Event, sender: CustomStringConvertible, args: Arguments) {
    let drone = sender as! TelloSwift
    if event == drone.EVENT_FLIGHT_DATA {
        print(String(bytes: args.data!, encoding: .utf8) ?? "")
    }
}

let drone = TelloSwift()
drone.subscribe(signal: drone.EVENT_FLIGHT_DATA, handler: handler)
drone.connect()
try! drone.wait_for_connection(timeout: 60)
let video_stream = drone.get_video_stream()
drone.takeoff()
sleep(5)
drone.down(value: 50)
sleep(5)
drone.land()
sleep(50)
drone.quit()

