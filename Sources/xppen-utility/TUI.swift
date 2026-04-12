import Foundation
import IOKit.hid

struct PhysicalKeyMapping {
    let modifiers: UInt8
    let scancode: UInt8
}

struct DeviceState {
    var currentModifiers: UInt8 = 0
    var currentScancode: UInt8 = 0
    var eventLog: [String] = []
    var lastReport: Data?
    var lastReportID: Int?
    var lastSenderInfo: String = ""
    var lastDialAction: String = "None"
    
    var isAnyKeyDown = false
    var dialCenterToggled = false
    var seenInterfaces: Set<String> = []
    
    // Pulse timers for momentary events
    var dialCWPulseTimer: Date?
    var dialCCWPulseTimer: Date?
    
    var isCWActive: Bool {
        guard let t = dialCWPulseTimer else { return false }
        return Date().timeIntervalSince(t) < 0.1
    }
    var isCCWActive: Bool {
        guard let t = dialCCWPulseTimer else { return false }
        return Date().timeIntervalSince(t) < 0.1
    }
    
    let mappings: [String: PhysicalKeyMapping] = [
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
    let keyNames = ["K1", "K2", "K3", "K4", "K5", "K6", "K7", "K8", "K9", "K10"]

    mutating func update(with report: Data, reportID: Int, sender: IOHIDDevice) -> Bool {
        lastReport = report
        lastReportID = reportID
        
        let up = IOHIDDeviceGetProperty(sender, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let u = IOHIDDeviceGetProperty(sender, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        let ptr = Unmanaged.passUnretained(sender).toOpaque()
        let interfaceID = "Usage \(up):\(u) @ \(ptr)"
        seenInterfaces.insert(interfaceID)
        lastSenderInfo = interfaceID
        
        var needsPulseCleanup = false
        
        if reportID == 6 && report.count >= 3 {
            let isNull = report.dropFirst().allSatisfy { $0 == 0 }
            if isNull {
                if !isAnyKeyDown {
                    dialCenterToggled.toggle()
                    lastDialAction = dialCenterToggled ? "CENTER DOWN" : "CENTER UP"
                }
                isAnyKeyDown = false
                currentModifiers = 0
                currentScancode = 0
            } else {
                currentModifiers = report[1]
                currentScancode = report[2]
                isAnyKeyDown = true
            }
        }
        
        if isPressed("DIAL_CW") { 
            lastDialAction = "Clockwise ↻"
            dialCWPulseTimer = Date()
            needsPulseCleanup = true
        } else if isPressed("DIAL_CCW") { 
            lastDialAction = "Counter-Clockwise ↺"
            dialCCWPulseTimer = Date()
            needsPulseCleanup = true
        }
        
        let activeKeys = keyNames.filter { isPressed($0) }
        let keysStr = activeKeys.isEmpty ? "[]" : "[\(activeKeys.joined(separator: ", "))]"
        let msg = "[\(currentTime())] \(lastSenderInfo) | ID: \(reportID) | \(report.map { String(format: "%02X", $0) }.joined(separator: " ")) | \(keysStr)"
        
        eventLog.insert(msg, at: 0)
        if eventLog.count > 15 { eventLog.removeLast() }
        
        return needsPulseCleanup
    }
    
    func isPressed(_ k: String) -> Bool {
        guard let mapping = mappings[k], isAnyKeyDown else { return false }
        return currentScancode == mapping.scancode && currentModifiers == mapping.modifiers
    }
    
    private func currentTime() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}

class Canvas {
    var grid: [[String]]
    let width: Int
    let height: Int
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.grid = Array(repeating: Array(repeating: " ", count: width), count: height)
    }
    func draw(lines: [String], x: Int, y: Int) {
        for (i, line) in lines.enumerated() {
            let targetY = y + i
            if targetY < height {
                let visual = line.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
                if x < width {
                    grid[targetY][x] = line
                    for j in 1..<visual.count { if x + j < width { grid[targetY][x+j] = "" } }
                }
            }
        }
    }
    func render() { for row in grid { print(row.joined()) } }
}

struct TUIBox {
    static func render(label: String, w: Int, h: Int, isPressed: Bool) -> [String] {
        let colorStart = isPressed ? "\u{1B}[1;32m" : ""
        let colorEnd = isPressed ? "\u{1B}[0m" : ""
        var lines: [String] = ["╭" + String(repeating: "─", count: w - 2) + "╮"]
        let paddedLabel = center(label.count > (w-2) ? String(label.prefix(w-2)) : label, width: w - 2)
        for i in 0..<(h - 2) {
            if i == (h - 2) / 2 { lines.append("│" + colorStart + paddedLabel + colorEnd + "│") }
            else { lines.append("│" + String(repeating: " ", count: w - 2) + "│") }
        }
        lines.append("╰" + String(repeating: "─", count: w - 2) + "╯")
        return lines
    }
    private static func center(_ text: String, width: Int) -> String {
        let p = width - text.count; if p <= 0 { return text }
        let l = p / 2; return String(repeating: " ", count: l) + text + String(repeating: " ", count: p - l)
    }
}

class TUI: @unchecked Sendable {
    var state = DeviceState()
    private var logFile: FileHandle?
    
    init() {
        let logPath = "xppen_events.log"
        if !FileManager.default.fileExists(atPath: logPath) { FileManager.default.createFile(atPath: logPath, contents: nil, attributes: nil) }
        logFile = FileHandle(forWritingAtPath: logPath); logFile?.seekToEndOfFile()
    }
    
    func update(report: Data, reportID: Int, sender: IOHIDDevice) {
        let needsCleanup = state.update(with: report, reportID: reportID, sender: sender)
        let logMsg = state.eventLog.first ?? ""
        if let data = (logMsg + "\n").data(using: .utf8) { logFile?.write(data) }
        draw()
        
        if needsCleanup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.draw()
            }
        }
    }
    
    func draw() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        print("\u{1B}[1mXP-Pen Shortcut Pad Utility\u{1B}[0m")
        print("---------------------------")
        let canvas = Canvas(width: 60, height: 13)
        let cw = state.isCWActive; let ccw = state.isCCWActive; let center = state.dialCenterToggled
        let cCol = center ? "\u{1B}[1;32m" : ""; let cwCol = cw ? "\u{1B}[1;32m" : ""; let ccwCol = ccw ? "\u{1B}[1;32m" : ""; let res = (cw || ccw || center) ? "\u{1B}[0m" : ""
        canvas.draw(lines: [
            "    ╭───────╮    ",
            "  ╭─╯       ╰─╮  ",
            "  │ \(ccwCol)↺\(res)   \(cCol)●\(res)   \(cwCol)↻\(res) │  ",
            "  ╰─╮       ╭─╯  ",
            "    ╰───────╯    "
        ], x: 0, y: 2)
        let startX = 20; let colW = 7; let rowH = 4
        func drawKey(_ n: String, c: Int, r: Int, w: Int = 6, h: Int = 3) { canvas.draw(lines: TUIBox.render(label: n, w: w, h: h, isPressed: state.isPressed(n)), x: startX + (c * colW), y: 1 + (r * rowH)) }
        drawKey("K1", c: 0, r: 0); drawKey("K2", c: 1, r: 0); drawKey("K3", c: 2, r: 0)
        canvas.draw(lines: TUIBox.render(label: "K7", w: 6, h: 7, isPressed: state.isPressed("K7")), x: startX + (3 * colW), y: 1)
        drawKey("K4", c: 0, r: 1); drawKey("K5", c: 1, r: 1); drawKey("K6", c: 2, r: 1); drawKey("K8", c: 0, r: 2)
        canvas.draw(lines: TUIBox.render(label: "K9", w: 13, h: 3, isPressed: state.isPressed("K9")), x: startX + (1 * colW), y: 1 + (2 * rowH))
        drawKey("K10", c: 3, r: 2); canvas.render()
        print("\n\u{1B}[1mAction State: \(state.lastDialAction)\u{1B}[0m\n\u{1B}[1mInteraction Log:\u{1B}[0m")
        for event in state.eventLog.prefix(4) { print(event) }
        print("\nPress Ctrl+C to exit. Log: xppen_events.log")
    }
}
