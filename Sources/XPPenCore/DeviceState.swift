import Foundation
import IOKit.hid

public struct PhysicalKeyMapping {
    public let modifiers: UInt8
    public let scancode: UInt8
    
    public init(modifiers: UInt8, scancode: UInt8) {
        self.modifiers = modifiers
        self.scancode = scancode
    }
}

public struct DeviceState {
    public var currentModifiers: UInt8 = 0
    public var currentScancode: UInt8 = 0
    public var eventLog: [String] = []
    public var lastReport: Data?
    public var lastReportID: Int?
    public var lastSenderInfo: String = ""
    public var lastDialAction: String = "None"
    
    public var isAnyKeyDown = false
    public var centerPulseTimer: Date?
    public var isCenterActive: Bool {
        guard let t = centerPulseTimer else { return false }
        return Date().timeIntervalSince(t) < 0.2
    }
    
    public var dialCWPulseTimer: Date?
    public var dialCCWPulseTimer: Date?
    public var isCWActive: Bool { guard let t = dialCWPulseTimer else { return false }; return Date().timeIntervalSince(t) < 0.1 }
    public var isCCWActive: Bool { guard let t = dialCCWPulseTimer else { return false }; return Date().timeIntervalSince(t) < 0.1 }
    
    public var seenDevices: [Int: Set<String>] = [:]
    
    public let mappings: [String: PhysicalKeyMapping] = [
        "K1": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x12),
        "K2": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x11),
        "K3": PhysicalKeyMapping(modifiers: 0x00, scancode: 0x3E),
        "K4": PhysicalKeyMapping(modifiers: 0x02, scancode: 0x00),
        "K5": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x00),
        "K6": PhysicalKeyMapping(modifiers: 0x04, scancode: 0x00),
        "K7": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x16),
        "K8": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x1D),
        "K9": PhysicalKeyMapping(modifiers: 0x00, scancode: 0x2C),
        "K10": PhysicalKeyMapping(modifiers: 0x03, scancode: 0x1D),
        "DIAL_CW": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x57),
        "DIAL_CCW": PhysicalKeyMapping(modifiers: 0x01, scancode: 0x56)
    ]
    public let keyNames = ["K1", "K2", "K3", "K4", "K5", "K6", "K7", "K8", "K9", "K10"]

    public init() {}

    public mutating func update(with report: Data, reportID: Int, sender: IOHIDDevice) {
        lastReport = report
        lastReportID = reportID
        
        let pid = IOHIDDeviceGetProperty(sender, kIOHIDProductIDKey as CFString) as? Int ?? 0
        if pid != 514 { return } // Only log ACK05
        
        let up = IOHIDDeviceGetProperty(sender, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let u = IOHIDDeviceGetProperty(sender, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        let info = "Usage:\(up):\(u)"
        seenDevices[pid, default: []].insert("\(up):\(u)")
        lastSenderInfo = info
        
        let hex = report.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        if reportID == 6 && report.count >= 3 {
            let isNull = report.dropFirst().allSatisfy { $0 == 0 }
            if isNull && !isAnyKeyDown {
                centerPulseTimer = Date()
                lastDialAction = "CENTER PULSE"
            }
            isAnyKeyDown = !isNull
            if !isNull {
                currentModifiers = report[1]
                currentScancode = report[2]
            }
        }
        
        if reportID == 1 && hex.contains("01 71 00") {
            centerPulseTimer = Date()
            lastDialAction = "ID 1 SIGNATURE"
        }
        
        if isPressed("DIAL_CW") { lastDialAction = "Clockwise ↻"; dialCWPulseTimer = Date() }
        else if isPressed("DIAL_CCW") { lastDialAction = "Counter-Clockwise ↺"; dialCCWPulseTimer = Date() }
        
        let activeKeys = keyNames.filter { isPressed($0) }
        let keysStr = activeKeys.isEmpty ? "[]" : "[\(activeKeys.joined(separator: ", "))]"
        let msg = "[\(currentTime())] ID:\(reportID) | \(hex) | \(keysStr)"
        eventLog.insert(msg, at: 0)
        if eventLog.count > 15 { eventLog.removeLast() }
    }
    
    public func isPressed(_ k: String) -> Bool {
        guard let mapping = mappings[k], isAnyKeyDown, lastReportID == 6 else { return false }
        return currentScancode == mapping.scancode && currentModifiers == mapping.modifiers
    }
    
    private func currentTime() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
