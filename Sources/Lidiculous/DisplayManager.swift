// Lidiculous
// Copyright © 2025 @ciutadellla. All rights reserved.

import AppKit
import CoreGraphics
import Darwin
import Foundation

private typealias CGSConfigureDisplayEnabledFn =
    @convention(c) (OpaquePointer, CGDirectDisplayID, Bool) -> CGError

private let _cgsConfigure: CGSConfigureDisplayEnabledFn? = {
    let paths = [
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    ]
    for path in paths {
        guard let handle = dlopen(path, RTLD_LAZY),
              let sym    = dlsym(handle, "CGSConfigureDisplayEnabled")
        else { continue }
        return unsafeBitCast(sym, to: CGSConfigureDisplayEnabledFn.self)
    }
    return nil
}()

private func nativeSetEnabled(_ display: CGDirectDisplayID, _ enabled: Bool) -> Bool {
    guard let fn = _cgsConfigure else { return false }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else { return false }
    let ok = fn(cfg, display, enabled)
    if ok == .success {
        CGCompleteDisplayConfiguration(cfg, .permanently)
        return true
    } else {
        CGCancelDisplayConfiguration(cfg)
        return false
    }
}

struct DisplayInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let isBuiltin: Bool
    let isOnline: Bool
    let isActive: Bool
    let bounds: CGRect
    let name: String

    var isDisabled: Bool { isOnline && !isActive }
    var displayName: String {
        isBuiltin ? "Built-in Retina Display" : (name.isEmpty ? "External Display" : name)
    }
}

@MainActor
final class DisplayManager: ObservableObject {

    static let shared = DisplayManager()

    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var builtinDisabled = false
    @Published var statusMessage = "Monitoring displays…"
    @Published var lastError: String? = nil

    @Published var autoToggleEnabled: Bool {
        didSet { UserDefaults.standard.set(autoToggleEnabled, forKey: "autoToggleEnabled") }
    }

    var launchAtLogin: Bool {
        get { FileManager.default.fileExists(atPath: launchAgentURL.path) }
        set {
            do {
                if newValue { try installLaunchAgent() } else { try removeLaunchAgent() }
            } catch {
                lastError = "Launch at Login: \(error.localizedDescription)"
            }
            objectWillChange.send()
        }
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.yourdomain.Lidiculous.plist")
    }

    private func installLaunchAgent() throws {
        let execPath = Bundle.main.bundlePath + "/Contents/MacOS/Lidiculous"
        let plist: [String: Any] = [
            "Label":            "com.yourdomain.Lidiculous",
            "ProgramArguments": [execPath],
            "RunAtLoad":        true,
            "KeepAlive":        false,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: launchAgentURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: launchAgentURL)
    }

    private func removeLaunchAgent() throws {
        guard FileManager.default.fileExists(atPath: launchAgentURL.path) else { return }
        try FileManager.default.removeItem(at: launchAgentURL)
    }

    let apiResolved: Bool = (_cgsConfigure != nil)
    var apiStatus: String { apiResolved ? "CGSConfigureDisplayEnabled ✓" : "API not found ✗" }
    private(set) var cachedBuiltinID: CGDirectDisplayID? = nil
    private var rememberedBuiltinIDs: Set<CGDirectDisplayID> = []

    private var cachedBuiltinInfo: DisplayInfo? = nil
    private var wasExternalConnected = false

    private init() {
        autoToggleEnabled = UserDefaults.standard.bool(forKey: "autoToggleEnabled")
        let savedID = UserDefaults.standard.integer(forKey: "builtinDisplayID")
        if savedID > 0 { rememberedBuiltinIDs.insert(CGDirectDisplayID(savedID)) }
        refresh()
        wasExternalConnected = !activeExternalIDsFromSystem().isEmpty
        registerHardwareCallback()
    }

    func refresh() {
        var onlineCount: UInt32 = 0
        CGGetOnlineDisplayList(32, nil, &onlineCount)
        var onlineIDs = [CGDirectDisplayID](repeating: 0, count: Int(onlineCount))
        CGGetOnlineDisplayList(onlineCount, &onlineIDs, &onlineCount)

        var activeCount: UInt32 = 0
        CGGetActiveDisplayList(32, nil, &activeCount)
        var activeIDs = [CGDirectDisplayID](repeating: 0, count: Int(activeCount))
        CGGetActiveDisplayList(activeCount, &activeIDs, &activeCount)
        let activeSet = Set(activeIDs)

        var infos = onlineIDs.map { did -> DisplayInfo in
            let isBuiltin = CGDisplayIsBuiltin(did) != 0 || rememberedBuiltinIDs.contains(did)
            return DisplayInfo(
                id: did,
                isBuiltin: isBuiltin,
                isOnline: true,
                isActive: activeSet.contains(did),
                bounds: CGDisplayBounds(did),
                name: screenNameFor(did)
            )
        }

        if !infos.contains(where: \.isBuiltin) {
            if let cached = cachedBuiltinInfo {
                infos.insert(DisplayInfo(id: cached.id, isBuiltin: true, isOnline: true,
                                         isActive: false, bounds: cached.bounds, name: cached.name), at: 0)
            } else {
                let savedID = UserDefaults.standard.integer(forKey: "builtinDisplayID")
                if savedID > 0 {
                    let w = UserDefaults.standard.double(forKey: "builtinBoundsW")
                    let h = UserDefaults.standard.double(forKey: "builtinBoundsH")
                    let savedName = UserDefaults.standard.string(forKey: "builtinName") ?? ""
                    let did = CGDirectDisplayID(savedID)
                    let bounds = w > 0 ? CGRect(x: 0, y: 0, width: w, height: h) : .zero
                    infos.insert(DisplayInfo(id: did, isBuiltin: true, isOnline: true,
                                             isActive: false, bounds: bounds, name: savedName), at: 0)
                    rememberedBuiltinIDs.insert(did)
                }
            }
        }

        if let real = infos.first(where: { $0.isBuiltin && $0.isActive }) {
            cachedBuiltinInfo = real
            rememberedBuiltinIDs.insert(real.id)
            UserDefaults.standard.set(Int(real.id), forKey: "builtinDisplayID")
            UserDefaults.standard.set(Double(real.bounds.width), forKey: "builtinBoundsW")
            UserDefaults.standard.set(Double(real.bounds.height), forKey: "builtinBoundsH")
            UserDefaults.standard.set(real.name, forKey: "builtinName")
        }
        for info in infos where info.isBuiltin {
            rememberedBuiltinIDs.insert(info.id)
        }

        displays = infos.sorted { $0.isBuiltin && !$1.isBuiltin }
        builtinDisabled = displays.first(where: \.isBuiltin)?.isDisabled ?? false
        rebuildStatus()

        if !displays.contains(where: { !$0.isBuiltin && $0.isActive }) && builtinDisabled {
            enableBuiltin()
        }
    }

    func toggleBuiltin() {
        refresh()
        guard let builtin = displays.first(where: \.isBuiltin) else {
            lastError = "No built-in display found."; return
        }
        if builtin.isDisabled {
            enableBuiltin()
        } else {
            guard displays.contains(where: { !$0.isBuiltin && $0.isActive }) else {
                lastError = "Connect an external display first."; return
            }
            disableBuiltin()
        }
    }

    func autoDisableOnLaunchIfNeeded() {
        refresh()
        guard launchAtLogin,
              !builtinDisabled,
              !activeExternalIDsFromSystem().isEmpty else { return }
        disableBuiltin()
    }

    func handleSystemWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refresh()
        }
    }

    func handleDisplayChange() {
        let externalNow = !activeExternalIDsFromSystem().isEmpty
        let externalJustConnected = externalNow && !wasExternalConnected
        wasExternalConnected = externalNow
        refresh()

        if autoToggleEnabled && externalJustConnected && !builtinDisabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self,
                      !self.activeExternalIDsFromSystem().isEmpty,
                      !self.builtinDisabled else { return }
                self.disableBuiltin()
            }
        }
    }

    func enableAll() {
        var candidates = Set<CGDirectDisplayID>()
        if let id = cachedBuiltinID { candidates.insert(id) }
        if let info = cachedBuiltinInfo { candidates.insert(info.id) }
        candidates.formUnion(rememberedBuiltinIDs)
        candidates.insert(CGMainDisplayID())

        var onlineCount: UInt32 = 0
        CGGetOnlineDisplayList(32, nil, &onlineCount)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(onlineCount))
        CGGetOnlineDisplayList(onlineCount, &ids, &onlineCount)
        for did in ids.prefix(Int(onlineCount)) { candidates.insert(did) }

        for did in candidates where did != 0 { _ = nativeSetEnabled(did, true) }
        cachedBuiltinID = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if !self.isBuiltinActiveFromSystem() {
                for did in candidates where did != 0 { _ = nativeSetEnabled(did, true) }
                self.refresh()
            }
        }
    }

    private func disableBuiltin() {
        guard let b = displays.first(where: \.isBuiltin), !b.isDisabled else { return }
        if nativeSetEnabled(b.id, false) {
            cachedBuiltinID = b.id
            lastError = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
        } else {
            lastError = "CGSConfigureDisplayEnabled not resolved — \(apiStatus)"
        }
    }

    private func enableBuiltin() {
        let id = cachedBuiltinID ?? displays.first(where: \.isBuiltin)?.id
        guard let id else { return }
        _ = nativeSetEnabled(id, true)
        cachedBuiltinID = nil
        lastError = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    private func rebuildStatus() {
        let ext = displays.filter { !$0.isBuiltin && $0.isActive }
        if ext.isEmpty {
            statusMessage = builtinDisabled ? "⚠️ No external — re-enabling built-in"
                                           : "Waiting for external display…"
        } else {
            let count = ext.count
            statusMessage = builtinDisabled
                ? "\(count) external active · Built-in off"
                : "\(count) external display\(count == 1 ? "" : "s") active"
        }
    }

    private func activeExternalIDsFromSystem() -> Set<CGDirectDisplayID> {
        var count: UInt32 = 0
        CGGetActiveDisplayList(32, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return Set(ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 })
    }

    private func isBuiltinActiveFromSystem() -> Bool {
        var count: UInt32 = 0
        CGGetActiveDisplayList(32, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) != 0 }
    }

    private func screenNameFor(_ did: CGDirectDisplayID) -> String {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == did
        }?.localizedName ?? ""
    }

    private func registerHardwareCallback() {
        CGDisplayRegisterReconfigurationCallback({ _, flags, ctx in
            guard let ctx, !flags.contains(.beginConfigurationFlag) else { return }
            let mgr = Unmanaged<DisplayManager>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { mgr.handleDisplayChange() }
        }, Unmanaged.passUnretained(self).toOpaque())
    }
}
