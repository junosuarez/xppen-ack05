import Foundation
import CoreGraphics

public enum ACK05Action {
    case shell(String)
    case keySequence([UInt16], [CGEventFlags]) // Now supports multiple keys
}

public class ActionExecutor {
    public init() {}
    
    public func execute(_ action: ACK05Action) {
        switch action {
        case .shell(let command):
            print("Executing Shell: \(command)")
            fflush(stdout)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            try? process.run()
            
        case .keySequence(let keyCodes, let flags):
            let source = CGEventSource(stateID: .hidSystemState)
            
            for (index, keyCode) in keyCodes.enumerated() {
                let currentFlags = index < flags.count ? flags[index] : CGEventFlags()
                print("Synthesizing KeyCode: \(keyCode) Flags: \(currentFlags.rawValue)")
                fflush(stdout)
                
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                
                // Tag events as synthesized by us
                keyDown?.setIntegerValueField(.eventSourceUserData, value: 0xAC05)
                keyUp?.setIntegerValueField(.eventSourceUserData, value: 0xAC05)
                
                keyDown?.flags = currentFlags
                keyUp?.flags = currentFlags
                
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
                
                // Small delay between chord components to ensure app compatibility
                if keyCodes.count > 1 {
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
        }
    }
}
