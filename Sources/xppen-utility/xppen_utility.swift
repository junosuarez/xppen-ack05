import Foundation
import IOKit.hid

@main
struct XPPenUtility {
    static func main() {
        let hidManager = HIDManager()
        let devices = hidManager.findDevices()
        
        let vendorID = 10429
        let productID = 514
        
        let xppenDevices = devices.filter { device in
            let v = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
            let p = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
            return v == vendorID && p == productID
        }
        
        if xppenDevices.isEmpty {
            print("XP-Pen Shortcut Pad not found.")
            return
        }
        
        print("Auditing interfaces for Magic Knock...")
        var vendorInterface: IOHIDDevice?
        
        for device in xppenDevices {
            let up = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
            let u = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
            let ptr = Unmanaged.passUnretained(device).toOpaque()
            print("  Usage: \(String(format: "%04X", up)):\(String(format: "%04X", u)) @ \(ptr)")
            
            if up == 0xff0a && u == 0x01 {
                vendorInterface = device
                print("    *** FOUND VENDOR INTERFACE ***")
            }
        }
        
        let tui = TUI()
        hidManager.onInputReport = { data, reportID, sender in
            tui.update(report: data, reportID: reportID, sender: sender)
        }
        
        if let vDevice = vendorInterface {
            print("\nSending Magic Knock to Vendor Interface...")
            // The Rust driver uses report ID 0x02.
            // Packet: 02 B0 04 00 00 00 00 00 00 00
            var command: [UInt8] = [0x02, 0xb0, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
            let res = IOHIDDeviceSetReport(vDevice, kIOHIDReportTypeOutput, 0x02, &command, command.count)
            if res == kIOReturnSuccess {
                print("Magic Knock SUCCESS!")
            } else {
                print("Magic Knock FAILED: \(res) (Try sudo?)")
            }
        }
        
        tui.draw()
        hidManager.start(vendorID: vendorID, productID: productID)
    }
}
