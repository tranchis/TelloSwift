# DJI Tello drone controller Swift framework

This is a Swift framework that allows controlling the DJI Tello drone, presumably from iOS and macOS (although it hasn't been thoroughly tested yet).

The code in this repo is almost a line-to-line translation of the [Python package](https://github.com/hanyazou/TelloPy), so some refactoring is expected soon. Also many interface operations such as moving and tilting the drone in different directions are not yet fully implemented.

## How to test

There are still not enough tests to be confident that this framework can be used reliably. *Please use at your own risk.*

If you want to do a quick test, run the playground at `TelloSwiftFrameworkTests/TakeoffExample.playground`.
