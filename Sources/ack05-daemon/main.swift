import Foundation
import XPPenCore
import CoreGraphics

@MainActor
class DaemonState {
    let hidManager = HIDManager()
    var deviceState = DeviceState()
    let executor = ActionExecutor()
    let configManager = ConfigManager()
    var currentConfig: AppConfig
    var lastActionedKeys: Set<String> = []
    var wasCenterActive = false
    
    // File watcher
    private var configWatcher: DispatchSourceFileSystemObject?
    
    init() { 
        self.currentConfig = ConfigManager().load()
        setupWatcher()
    }
    
    func setupWatcher() {
        let path = configManager.getConfigPath()
        let fileDescriptor = open(path, O_EVTONLY)
        if fileDescriptor == -1 { return }
        
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: .main)
        
        watcher.setEventHandler { [weak self] in
            Task { @MainActor in
                print("Config file change detected. Reloading...")
                self?.currentConfig = self?.configManager.load() ?? AppConfig(mappings: [:])
            }
        }
        
        watcher.setCancelHandler {
            close(fileDescriptor)
        }
        
        watcher.resume()
        self.configWatcher = watcher
    }
    
    func execute(_ config: ConfiguredAction) {
        switch config.type {
        case .shell:
            executor.execute(.shell(config.value))
        case .key, .chord:
            let keyStrings = config.value.split(separator: ",")
            let keyCodes = keyStrings.compactMap { UInt16($0) }
            let modifiers = config.modifiers?.map { CGEventFlags(rawValue: $0) } ?? []
            executor.execute(.keySequence(keyCodes, modifiers))
        case .none:
            break
        }
    }
    
    func run() {
        let vendorID = 10429
        hidManager.onInputReport = { data, reportID, sender in
            Task { @MainActor in self.handleReport(data: data, reportID: reportID, sender: sender) }
        }
        print("ACK05-B Daemon Started.")
        print("Monitoring config at: \(configManager.getConfigPath())")
        hidManager.start(vendorID: vendorID)
    }
    
    private func handleReport(data: Data, reportID: Int, sender: IOHIDDevice) {
        deviceState.update(with: data, reportID: reportID, sender: sender)
        let allInputs = deviceState.keyNames + ["DIAL_CW", "DIAL_CCW"]
        for input in allInputs {
            if deviceState.isPressed(input) {
                if !lastActionedKeys.contains(input) {
                    if let action = currentConfig.mappings[input] { execute(action) }
                    lastActionedKeys.insert(input)
                }
            } else { lastActionedKeys.remove(input) }
        }
        if deviceState.isCenterActive {
            if !wasCenterActive {
                if let action = currentConfig.mappings["CENTER"] { execute(action) }
                wasCenterActive = true
            }
        } else { wasCenterActive = false }
    }
}

let daemon = DaemonState()
daemon.run()
