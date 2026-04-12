import Foundation
import IOKit.hid

class HIDManager {
    private let manager: IOHIDManager
    var onInputReport: ((Data, Int, IOHIDDevice) -> Void)?
    
    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    }
    
    func findDevices() -> [IOHIDDevice] {
        IOHIDManagerSetDeviceMatching(manager, nil)
        let deviceSet = IOHIDManagerCopyDevices(manager)
        if let deviceSet = deviceSet as? Set<IOHIDDevice> {
            return Array(deviceSet)
        }
        return []
    }
    
    func start(vendorID: Int, productID: Int) {
        let matchingDict: [String: Any] = [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDProductIDKey: productID
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
        if res != kIOReturnSuccess {
            IOHIDManagerOpen(manager, 0)
        }
        
        CFRunLoopRun()
    }
}
