import XCTest
import Foundation
@testable import XPPenCore

final class XPPenCoreTests: XCTestCase {
    
    // Test that raw HID reports correctly map to logical keys
    func testDeviceStateDecoding() {
        var state = DeviceState()
        
        // Mock a sender device
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>
        guard let device = devices?.first else { return }
        
        // 1. Test K1 (Ctrl + O) -> 06 01 12 ...
        let k1Report = Data([0x06, 0x01, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00])
        state.update(with: k1Report, reportID: 6, sender: device)
        XCTAssertTrue(state.isPressed("K1"), "K1 should be pressed for report 06 01 12")
        XCTAssertFalse(state.isPressed("K5"), "K5 (Ctrl) should NOT be pressed due to subset suppression")
        
        // 2. Test Dial CW (Ctrl + Keypad +) -> 06 01 57 ...
        let cwReport = Data([0x06, 0x01, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00])
        state.update(with: cwReport, reportID: 6, sender: device)
        XCTAssertTrue(state.isPressed("DIAL_CW"), "Dial CW should be detected")
        
        // 3. Test Null Report (Release)
        let nullReport = Data([0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        state.update(with: nullReport, reportID: 6, sender: device)
        XCTAssertFalse(state.isAnyKeyDown, "All keys should be up after null report")
    }
    
    // Test the heuristic detection for the Center Button
    func testCenterButtonHeuristic() {
        var state = DeviceState()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>
        guard let device = devices?.first else { return }
        
        // Initial Null report (system state sync)
        let nullReport = Data([0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        state.update(with: nullReport, reportID: 6, sender: device)
        XCTAssertFalse(state.isCenterActive)
        
        // Center button press (unexpected null)
        state.update(with: nullReport, reportID: 6, sender: device)
        XCTAssertTrue(state.isCenterActive, "Unexpected null report should trigger center button pulse")
    }
    
    // Test JSON Serialization
    func testConfigSerialization() {
        var config = AppConfig()
        config.mappings["K1"] = ConfiguredAction(
            type: .chord, 
            value: "12,13", 
            displayValue: "⌘K, ⌘S", 
            modifiers: [1048576, 1048576]
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(config)
            let decoded = try decoder.decode(AppConfig.self, from: data)
            XCTAssertEqual(decoded.mappings["K1"]?.value, "12,13")
            XCTAssertEqual(decoded.mappings["K1"]?.displayValue, "⌘K, ⌘S")
            XCTAssertEqual(decoded.mappings["K1"]?.modifiers?.count, 2)
        } catch {
            XCTFail("Serialization failed: \(error)")
        }
    }
}
