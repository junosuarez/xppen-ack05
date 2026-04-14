import Foundation
import CoreGraphics

public class EventInterceptor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    
    // KeyCodes to suppress
    private var activeKeyCodes: Set<CGKeyCode> = []
    private var activeFlags: CGEventFlags = []
    
    private let hidToMac: [UInt8: CGKeyCode] = [
        0x12: 31, // O
        0x11: 45, // N
        0x3E: 96, // F5
        0x16: 1,  // S
        0x1D: 6,  // Z
        0x2C: 49, // Space
        0x57: 69, // Keypad +
        0x56: 78, // Keypad -
        0x28: 36, // Enter (just in case)
    ]
    
    // Modifiers to KeyCodes
    private let modToKey: [UInt8: CGKeyCode] = [
        0x01: 59, // Control
        0x02: 56, // Shift
        0x04: 58, // Option
    ]
    
    public init() {
        setupTap()
    }
    
    private func setupTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let this = Unmanaged<EventInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                
                // If the event was created by us (ActionExecutor), let it through!
                if event.getIntegerValueField(.eventSourceUserData) == 0xAC05 {
                    return Unmanaged.passRetained(event)
                }
                
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                
                if type == .flagsChanged {
                    if this.activeKeyCodes.contains(keyCode) {
                        return nil // Swallow
                    }
                } else if type == .keyDown || type == .keyUp {
                    if this.activeKeyCodes.contains(keyCode) {
                        return nil // Swallow
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: observer
        ) else {
            print("Failed to create event tap. Accessibility permissions might be missing.")
            return
        }
        
        self.tap = tap
        self.source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    }
    
    public func getSource() -> CFRunLoopSource? {
        return source
    }
    
    public func update(modifiers: UInt8, scancode: UInt8) {
        var newActive: Set<CGKeyCode> = []
        
        // Map scancode
        if scancode != 0, let macKey = hidToMac[scancode] {
            newActive.insert(macKey)
        }
        
        // Map modifiers
        if modifiers & 0x01 != 0 { newActive.insert(59) } // Ctrl
        if modifiers & 0x02 != 0 { newActive.insert(56) } // Shift
        if modifiers & 0x04 != 0 { newActive.insert(58) } // Option
        
        self.activeKeyCodes = newActive
    }
}
