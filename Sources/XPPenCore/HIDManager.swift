import Foundation
import IOKit.hid

public class HIDManager {
    private let manager: IOHIDManager
    public var onInputReport: ((Data, Int, IOHIDDevice) -> Void)?
    
    public init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    }
    
    public func findDevices() -> [IOHIDDevice] {
        IOHIDManagerSetDeviceMatching(manager, nil)
        let deviceSet = IOHIDManagerCopyDevices(manager)
        if let deviceSet = deviceSet as? Set<IOHIDDevice> {
            return Array(deviceSet)
        }
        return []
    }
    
    public func start(vendorID: Int) {
        let matchingDict: [String: Any] = [
            kIOHIDVendorIDKey: vendorID
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterInputReportCallback(manager, { (context, result, sender, type, reportID, report, reportLength) in
            guard let context = context, let sender = sender else { return }
            let this = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
            let data = Data(bytes: report, count: reportLength)
            let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
            this.onInputReport?(data, Int(reportID), device)
        }, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        let res = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if res == kIOReturnSuccess {
            print("HID SEIZE SUCCESSFUL")
        } else {
            print("HID SEIZE FAILED: \(res) (Operating in non-exclusive mode)")
            IOHIDManagerOpen(manager, 0)
        }
        
        CFRunLoopRun()
    }
}
