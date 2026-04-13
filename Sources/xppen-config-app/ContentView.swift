import SwiftUI
import XPPenCore
import AppKit

@main
struct XPPenConfigApp: App {
    init() { NSApplication.shared.setActivationPolicy(.regular) }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 950, minHeight: 750)
                .background(WindowAccessor { window in
                    window.level = .floating
                    window.makeKeyAndOrderFront(nil)
                    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                        Task { @MainActor in NSApp.terminate(nil) }
                    }
                })
        }
        .windowStyle(.titleBar)
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView(); DispatchQueue.main.async { if let window = view.window { callback(window) } }; return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MappingRow: Identifiable {
    let id: String; let key: String; let action: ConfiguredAction; let isModified: Bool
}

struct ContentView: View {
    @State private var config: AppConfig; @State private var initialConfig: AppConfig; @State private var selectedKey: String? = nil
    let configManager = ConfigManager(); let allPhysicalKeys = [ "K1", "K2", "K3", "K4", "K5", "K6", "K7", "K8", "K9", "K10", "DIAL_CW", "DIAL_CCW", "CENTER" ]
    init() { let loaded = ConfigManager().load(); _config = State(initialValue: loaded); _initialConfig = State(initialValue: loaded) }
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                VStack(spacing: 0) {
                    DeviceLayoutView(selectedKey: $selectedKey, mappings: config.mappings).padding(.top, 40)
                    Spacer(); EditArea(key: selectedKey, action: bindingForSelectedKey()).padding().frame(height: 220).background(Color(NSColor.windowBackgroundColor))
                }.frame(maxWidth: .infinity).background(Color(NSColor.windowBackgroundColor))
                VStack(spacing: 0) {
                    HStack { Text("Mappings").font(.system(size: 13, weight: .bold)); Spacer(); Button(action: exportJSON) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.borderless).help("Export JSON") }.padding(10)
                    Divider(); MappingTable(selectedKey: $selectedKey, allKeys: allPhysicalKeys, currentMappings: config.mappings, baselineMappings: initialConfig.mappings)
                }.frame(width: 320).background(Color(NSColor.controlBackgroundColor))
            }
            Divider()
            HStack(spacing: 12) {
                Spacer(); Button("Cancel") { config = initialConfig; configManager.save(config); NSApp.terminate(nil) }.keyboardShortcut(.cancelAction)
                Button("OK") { configManager.save(config); NSApp.terminate(nil) }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }.padding(16).background(Color(NSColor.windowBackgroundColor))
        }
    }
    private func bindingForSelectedKey() -> Binding<ConfiguredAction> {
        Binding(get: { if let k = selectedKey { return config.mappings[k] ?? ConfiguredAction() }; return ConfiguredAction() }, set: { if let k = selectedKey { config.mappings[k] = $0; configManager.save(config) } })
    }
    private func exportJSON() {
        let savePanel = NSSavePanel(); savePanel.allowedContentTypes = [.json]; savePanel.nameFieldStringValue = "ack05_config.json"
        if savePanel.runModal() == .OK, let url = savePanel.url { try? JSONEncoder().encode(config).write(to: url) }
    }
}

struct DeviceBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); let w = rect.width; let h = rect.height; let sX = w / 1150; let sY = h / 750
        path.move(to: CGPoint(x: 300 * sX, y: 200 * sY)); path.addLine(to: CGPoint(x: 1039 * sX, y: 200 * sY))
        path.addQuadCurve(to: CGPoint(x: 1060 * sX, y: 221 * sY), control: CGPoint(x: 1060 * sX, y: 200 * sY)); path.addLine(to: CGPoint(x: 1060 * sX, y: 639 * sY))
        path.addQuadCurve(to: CGPoint(x: 1039 * sX, y: 660 * sY), control: CGPoint(x: 1060 * sX, y: 660 * sY)); path.addLine(to: CGPoint(x: 221 * sX, y: 660 * sY))
        path.addQuadCurve(to: CGPoint(x: 200 * sX, y: 639 * sY), control: CGPoint(x: 200 * sX, y: 660 * sY)); path.addLine(to: CGPoint(x: 200 * sX, y: 300 * sY))
        path.addArc(center: CGPoint(x: 275 * sX, y: 275 * sY), radius: 150 * sX, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath(); return path
    }
}

struct DeviceLayoutView: View {
    @Binding var selectedKey: String?; let mappings: [String: ConfiguredAction]
    let baseW: CGFloat = 1150; let baseH: CGFloat = 750
    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / baseW, geo.size.height / baseH)
            let oX = (geo.size.width - baseW * scale) / 2; let oY = (geo.size.height - baseH * scale) / 2
            ZStack(alignment: .topLeading) {
                DeviceBodyShape().fill(Color(NSColor.controlBackgroundColor)).frame(width: baseW * scale, height: baseH * scale).offset(x: oX, y: oY)
                DeviceBodyShape().stroke(Color.secondary.opacity(0.5), lineWidth: 2 * scale).frame(width: baseW * scale, height: baseH * scale).offset(x: oX, y: oY)
                ZStack {
                    Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 300 * scale, height: 300 * scale).overlay(Circle().stroke((selectedKey == "DIAL_CW" || selectedKey == "DIAL_CCW") ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 3 * scale))
                    KeyButton(name: "CENTER", label: "●", selectedKey: $selectedKey, mappings: mappings).clipShape(Circle()).frame(width: 150 * scale, height: 150 * scale)
                    indicatorButton(name: "DIAL_CCW", label: "↺", x: -105 * scale); indicatorButton(name: "DIAL_CW", label: "↻", x: 105 * scale)
                }.offset(x: oX + (275 - 150) * scale, y: oY + (275 - 150) * scale)
                Group {
                    rectKey("K1", x: 460, y: 230, w: 120, h: 120, scale: scale, offset: (oX, oY)); rectKey("K2", x: 600, y: 230, w: 120, h: 120, scale: scale, offset: (oX, oY)); rectKey("K3", x: 740, y: 230, w: 120, h: 120, scale: scale, offset: (oX, oY)); rectKey("K7", x: 880, y: 230, w: 120, h: 260, scale: scale, offset: (oX, oY))
                    rectKey("K4", x: 460, y: 370, w: 120, h: 120, scale: scale, offset: (oX, oY)); rectKey("K5", x: 600, y: 370, w: 120, h: 120, scale: scale, offset: (oX, oY)); rectKey("K6", x: 740, y: 370, w: 120, h: 120, scale: scale, offset: (oX, oY))
                    rectKey("K8", x: 460, y: 510, w: 120, h: 120, scale: scale, offset: (oX, oY)); rectKey("K9", x: 600, y: 510, w: 260, h: 120, scale: scale, offset: (oX, oY)); rectKey("K10", x: 880, y: 510, w: 120, h: 120, scale: scale, offset: (oX, oY))
                }
            }
        }
    }
    func rectKey(_ n: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, scale: CGFloat, offset: (CGFloat, CGFloat)) -> some View { KeyButton(name: n, label: n, selectedKey: $selectedKey, mappings: mappings).frame(width: w * scale, height: h * scale).offset(x: offset.0 + x * scale, y: offset.1 + y * scale) }
    func indicatorButton(name: String, label: String, x: CGFloat) -> some View {
        let isSelected = selectedKey == name; let hasMapping = (mappings[name]?.isValid ?? false)
        return Text(label).font(.system(size: 24, weight: .bold)).foregroundColor(isSelected ? Color.accentColor : (hasMapping ? Color.accentColor : .secondary)).onTapGesture { selectedKey = name }.offset(x: x)
    }
}

struct KeyButton: View {
    let name: String; let label: String; @Binding var selectedKey: String?; let mappings: [String: ConfiguredAction]
    var body: some View {
        let isSelected = selectedKey == name; let hasMapping = (mappings[name]?.isValid ?? false)
        return ZStack {
            RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor : (hasMapping ? Color.accentColor.opacity(0.15) : Color(NSColor.windowBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.white.opacity(0.5) : (hasMapping ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2)), lineWidth: 1))
            Text(label).font(.system(size: 13, weight: .bold)).foregroundColor(isSelected ? .white : (hasMapping ? Color.accentColor : .primary))
        }.onTapGesture { selectedKey = name }
    }
}

struct EditArea: View {
    let key: String?; @Binding var action: ConfiguredAction; @State private var isRecording = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(key != nil ? "Remapping: \(key!)" : "No Key Selected").font(.headline); Spacer(); if isRecording { Text("Recording...").foregroundColor(.red).italic() } }.frame(height: 20)
            if let _ = key {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Action Type:", selection: $action.type) { ForEach(ActionType.allCases, id: \.self) { type in Text(type.rawValue == "none" ? "None" : type.rawValue.capitalized).tag(type) } }.pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 8) {
                        if action.type == .shell {
                            VStack(alignment: .leading, spacing: 4) { Text("Shell Command:").font(.caption).foregroundColor(.secondary); TextField("e.g. open -a Ghostty", text: $action.value).textFieldStyle(.roundedBorder) }
                        } else if action.type == .key || action.type == .chord {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(action.type == .key ? "Single Keypress:" : "Key Chord Sequence:").font(.caption).foregroundColor(.secondary)
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6).fill(isRecording ? Color.red.opacity(0.05) : Color(NSColor.controlBackgroundColor))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isRecording ? Color.red : Color.secondary.opacity(0.2))).frame(height: 28)
                                        Text(isRecording ? "Press key..." : (action.displayValue ?? "None")).font(.system(.body, design: .monospaced)).foregroundColor(isRecording ? .red : .primary)
                                    }
                                    Button(isRecording ? "Stop" : "Record") {
                                        if !isRecording { action = ConfiguredAction(type: action.type, value: "", displayValue: "", modifiers: []); isRecording = true; NSApplication.shared.activate(ignoringOtherApps: true) }
                                        else { isRecording = false }
                                    }.buttonStyle(.bordered)
                                    if !isRecording && action.displayValue != nil && !action.displayValue!.isEmpty { Button("Clear") { action = ConfiguredAction(type: action.type, value: "", displayValue: "", modifiers: []) }.buttonStyle(.bordered) }
                                }
                                if action.type == .key && !isRecording && action.baseKey != nil { ModifierCheckboxes(action: $action).padding(.top, 4) }
                            }
                        } else { Color.clear }
                    }.frame(height: 100)
                }
            } else {
                VStack { Spacer(); Text("Select a key on the layout above to begin remapping").foregroundColor(.secondary).italic(); Spacer() }.frame(maxWidth: .infinity)
            }
        }.padding().background(Color(NSColor.controlBackgroundColor).opacity(0.5)).cornerRadius(12).overlay(Group { if isRecording { ShortcutGrabber(isRecording: $isRecording, action: $action, isChord: action.type == .chord) } })
    }
}

struct ModifierCheckboxes: View {
    @Binding var action: ConfiguredAction
    var body: some View {
        HStack(spacing: 12) { modifierToggle(label: "⌘ Cmd", bit: .command); modifierToggle(label: "⇧ Shift", bit: .shift); modifierToggle(label: "⌥ Opt", bit: .option); modifierToggle(label: "⌃ Ctrl", bit: .control) }
    }
    private func modifierToggle(label: String, bit: NSEvent.ModifierFlags) -> some View {
        let isSet = Binding(
            get: { NSEvent.ModifierFlags(rawValue: UInt(action.modifiers?.first ?? 0)).contains(bit) },
            set: { newValue in
                var current = NSEvent.ModifierFlags(rawValue: UInt(action.modifiers?.first ?? 0))
                if newValue { current.insert(bit) } else { current.remove(bit) }
                action.modifiers = [UInt64(current.rawValue)]
                action.displayValue = computeDisplayLabel(base: action.baseKey ?? "", shifted: action.shiftedKey ?? "", flags: current)
            }
        )
        return Toggle(label, isOn: isSet).toggleStyle(.checkbox).font(.caption)
    }
}

func computeDisplayLabel(base: String, shifted: String, flags: NSEvent.ModifierFlags) -> String {
    var modsStr = ""
    if flags.contains(.command) { modsStr += "⌘" }
    if flags.contains(.shift) && shifted == base.uppercased() { modsStr += "⇧" }
    if flags.contains(.option) { modsStr += "⌥" }; if flags.contains(.control) { modsStr += "⌃" }
    let char = flags.contains(.shift) ? shifted : base
    return "\(modsStr)\(char)"
}

struct ShortcutGrabber: View {
    @Binding var isRecording: Bool; @Binding var action: ConfiguredAction; let isChord: Bool
    @State private var monitor: Any?
    var body: some View {
        Color.white.opacity(0.001)
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if !isRecording { return event }
                    let keyCode = event.keyCode; if keyCode == 53 { isRecording = false; return nil }
                    let flags = event.modifierFlags; let chars = event.characters ?? ""; let charsNoShift = event.charactersIgnoringModifiers ?? ""
                    var baseK = ""; if keyCode == 49 { baseK = "Space" } else if keyCode == 36 { baseK = "Enter" } else { baseK = charsNoShift.uppercased() }
                    let shiftedK = (keyCode == 49 || keyCode == 36) ? baseK : chars
                    if isChord {
                        let newDisplay = computeDisplayLabel(base: baseK, shifted: shiftedK, flags: flags)
                        var cVal = action.value.split(separator: ",").map { String($0) }; var cDisp = action.displayValue?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } ?? []; var cMods = action.modifiers ?? []
                        cVal.append("\(keyCode)"); cDisp.append(newDisplay); cMods.append(UInt64(flags.rawValue))
                        action.value = cVal.joined(separator: ","); action.displayValue = cDisp.joined(separator: ", "); action.modifiers = cMods
                    } else {
                        action = ConfiguredAction(type: .key, value: "\(keyCode)", displayValue: computeDisplayLabel(base: baseK, shifted: shiftedK, flags: flags), baseKey: baseK, shiftedKey: shiftedK, modifiers: [UInt64(flags.rawValue)]); isRecording = false
                    }
                    return nil
                }
            }.onDisappear { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    }
}

struct MappingTable: View {
    @Binding var selectedKey: String?; let allKeys: [String]; let currentMappings: [String: ConfiguredAction]; let baselineMappings: [String: ConfiguredAction]
    var rows: [MappingRow] { allKeys.map { key in
        let current = currentMappings[key] ?? ConfiguredAction(); let baseline = baselineMappings[key] ?? ConfiguredAction()
        return MappingRow(id: key, key: key, action: current, isModified: current.isValid != baseline.isValid || (current.isValid && current != baseline))
    }}
    var body: some View {
        Table(rows, selection: $selectedKey) {
            TableColumn("Key") { row in HStack { if row.isModified { Circle().fill(Color.orange).frame(width: 6, height: 6) }; Text(row.key) } }
            TableColumn("Action") { row in
                if row.action.isValid {
                    let desc = (row.action.type == .key || row.action.type == .chord) ? (row.action.displayValue ?? row.action.value) : row.action.value
                    Text(desc).foregroundColor(row.isModified ? .orange : .accentColor)
                } else { Text("None").foregroundColor(.secondary).opacity(0.5) }
            }
        }
    }
}
extension String {
    func padding(toLength: Int, withPad: String, startingAt: Int) -> String {
        if self.count >= toLength { return String(self.prefix(toLength)) }
        let padCount = toLength - self.count; let pad = String(repeating: withPad, count: (padCount / withPad.count) + 1).prefix(padCount)
        return String(pad) + self
    }
}
