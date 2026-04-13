import Foundation

public enum ActionType: String, Codable, CaseIterable {
    case none
    case shell
    case key
    case chord
}

public struct ConfiguredAction: Codable, Equatable {
    public var type: ActionType
    public var value: String 
    public var displayValue: String?
    public var baseKey: String?
    public var shiftedKey: String?
    public var modifiers: [UInt64]? 
    
    public init(type: ActionType = .none, value: String = "", displayValue: String? = nil, baseKey: String? = nil, shiftedKey: String? = nil, modifiers: [UInt64]? = nil) {
        self.type = type
        self.value = value
        self.displayValue = displayValue
        self.baseKey = baseKey
        self.shiftedKey = shiftedKey
        self.modifiers = modifiers
    }
    
    public var isValid: Bool {
        if type == .none { return false }
        return !value.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

public struct AppConfig: Codable, Equatable {
    public var mappings: [String: ConfiguredAction]
    public init(mappings: [String: ConfiguredAction] = [:]) { self.mappings = mappings }
    public static var `default`: AppConfig { return AppConfig(mappings: [:]) }
}

public class ConfigManager {
    private let fileManager = FileManager.default
    public init() {}
    private var configURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("XPPenUtility")
        if !fileManager.fileExists(atPath: folder.path) { try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true) }
        return folder.appendingPathComponent("config.json")
    }
    
    public func load() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else { return .default }
        return config
    }
    
    public func save(_ config: AppConfig) {
        var cleanedMappings = config.mappings
        // Remove or reset invalid mappings so they don't persist as "half-full"
        for (key, action) in cleanedMappings {
            if !action.isValid {
                cleanedMappings.removeValue(forKey: key)
            }
        }
        
        let cleanedConfig = AppConfig(mappings: cleanedMappings)
        if let data = try? JSONEncoder().encode(cleanedConfig) {
            try? data.write(to: configURL)
        }
    }
    
    public func getConfigPath() -> String {
        return configURL.path
    }
}
