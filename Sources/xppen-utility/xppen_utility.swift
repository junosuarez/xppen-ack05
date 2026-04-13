import Foundation
import XPPenCore

@main
struct XPPenUtility {
    static func main() {
        let hidManager = HIDManager()
        let tui = TUI()
        
        let vendorID = 10429
        
        hidManager.onInputReport = { data, reportID, sender in
            tui.update(report: data, reportID: reportID, sender: sender)
        }
        
        // 20fps Redraw timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            tui.draw()
        }
        RunLoop.main.add(timer, forMode: .common)
        
        tui.log("--- STARTING TRACKER (Redraw @ 20fps) ---")
        
        // Start manager
        hidManager.start(vendorID: vendorID)
    }
}
