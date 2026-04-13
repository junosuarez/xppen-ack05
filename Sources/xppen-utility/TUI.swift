import Foundation
import XPPenCore

class TUI: @unchecked Sendable {
    var state = DeviceState()
    private var logFile: FileHandle?
    init() {
        let logPath = "xppen_events.log"
        if !FileManager.default.fileExists(atPath: logPath) { FileManager.default.createFile(atPath: logPath, contents: nil, attributes: nil) }
        logFile = FileHandle(forWritingAtPath: logPath); logFile?.seekToEndOfFile()
    }
    func log(_ msg: String) { if let data = (msg + "\n").data(using: .utf8) { logFile?.write(data) } }
    func update(report: Data, reportID: Int, sender: IOHIDDevice) {
        state.update(with: report, reportID: reportID, sender: sender)
        if let last = state.eventLog.first { log(last) }
    }
    func draw() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        print("\u{1B}[1mXP-Pen ACK05-B Tracker\u{1B}[0m\n-------------------------------------------------")
        if let report = state.lastReport {
            let hex = report.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("Interface: \(state.lastSenderInfo) | ID: \(state.lastReportID ?? 0)")
            print("Action: \u{1B}[1m\(state.lastDialAction)\u{1B}[0m  Data: \(hex)\n")
        }
        let view = ShortcutPadView(state: state)
        for line in view.render() { print(line) }
        print("\n\u{1B}[1mInteraction Log (ACK05 Only):\u{1B}[0m")
        for event in state.eventLog.prefix(5) { print(event) }
        print("\nPress Ctrl+C to exit. Log: xppen_events.log")
    }
}

class Canvas {
    var grid: [[String]]
    let width: Int; let height: Int
    init(width: Int, height: Int) { self.width = width; self.height = height; self.grid = Array(repeating: Array(repeating: " ", count: width), count: height) }
    func draw(lines: [String], x: Int, y: Int) {
        for (i, line) in lines.enumerated() {
            let targetY = y + i
            if targetY < height {
                let visual = line.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
                if x < width { grid[targetY][x] = line; for j in 1..<visual.count { if x + j < width { grid[targetY][x+j] = "" } } }
            }
        }
    }
    func render() { for row in grid { print(row.joined()) } }
}

struct TUIBox {
    static func render(label: String, w: Int, h: Int, isPressed: Bool) -> [String] {
        let colorStart = isPressed ? "\u{1B}[1;32m" : ""; let colorEnd = isPressed ? "\u{1B}[0m" : ""
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

struct ShortcutPadView {
    let state: DeviceState
    func render() -> [String] {
        func makeBox(_ name: String, w: Int = 7, h: Int = 3) -> [String] {
            var isPressed = false
            if state.mappings[name] != nil, state.isAnyKeyDown { isPressed = state.isPressed(name) }
            return TUIBox.render(label: name, w: w, h: h, isPressed: isPressed)
        }
        let cw = state.isCWActive; let ccw = state.isCCWActive; let center = state.isCenterActive
        let cwCol = cw ? "\u{1B}[1;32m" : ""; let ccwCol = ccw ? "\u{1B}[1;32m" : ""; let centerCol = center ? "\u{1B}[1;32m" : ""; let res = (cw || ccw || center) ? "\u{1B}[0m" : ""
        let dial = [ "    ╭───────╮    ", "  ╭─╯       ╰─╮  ", "  │ \(ccwCol)↺\(res)   \(centerCol)●\(res)   \(cwCol)↻\(res) │  ", "  ╰─╮       ╭─╯  ", "    ╰───────╯    " ]
        let k1 = makeBox("K1"); let k2 = makeBox("K2"); let k3 = makeBox("K3"); let k4 = makeBox("K4"); let k5 = makeBox("K5"); let k6 = makeBox("K6"); let k7 = TUIBox.render(label: "K7", w: 6, h: 7, isPressed: state.isPressed("K7")); let k8 = makeBox("K8"); let k9 = TUIBox.render(label: "K9", w: 13, h: 3, isPressed: state.isPressed("K9")); let k10 = makeBox("K10")
        let canvas = Canvas(width: 60, height: 13); canvas.draw(lines: dial, x: 0, y: 2); let startX = 20; let colW = 7
        canvas.draw(lines: k1, x: startX, y: 1); canvas.draw(lines: k2, x: startX + colW, y: 1); canvas.draw(lines: k3, x: startX + (2 * colW), y: 1); canvas.draw(lines: k7, x: startX + (3 * colW), y: 1); canvas.draw(lines: k4, x: startX, y: 5); canvas.draw(lines: k5, x: startX + colW, y: 5); canvas.draw(lines: k6, x: startX + (2 * colW), y: 5); canvas.draw(lines: k8, x: startX, y: 9); canvas.draw(lines: k9, x: startX + colW, y: 9); canvas.draw(lines: k10, x: startX + (3 * colW), y: 9)
        return canvas.grid.map { $0.joined() }
    }
}
