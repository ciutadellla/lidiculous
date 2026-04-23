// Lidiculous
// Copyright © 2025 @ciutadellla. All rights reserved.

import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var isIntentionalQuit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityIfNeeded()
        setupStatusItem()
        setupPopover()
        setupEventMonitor()

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                DisplayManager.shared.refresh()
                self?.ensureStatusItemVisible()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            DisplayManager.shared.autoDisableOnLaunchIfNeeded()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard isIntentionalQuit else { return .terminateCancel }
        DisplayManager.shared.enableAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !isIntentionalQuit { DisplayManager.shared.enableAll() }
    }

    @objc private func screenParametersChanged() {
        DisplayManager.shared.handleDisplayChange()
        updateIcon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.ensureStatusItemVisible()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.ensureStatusItemVisible()
        }
    }

    private func ensureStatusItemVisible() {
        if statusItem.button == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem.button {
                button.action = #selector(togglePopover(_:))
                button.target = self
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        }
        updateIcon()
    }

    func quit() {
        isIntentionalQuit = true
        NSApp.terminate(nil)
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let disabled = DisplayManager.shared.builtinDisabled
        let img = NSImage(systemSymbolName: disabled ? "display.slash" : "display",
                          accessibilityDescription: nil)
                  ?? NSImage(systemSymbolName: disabled ? "circle.slash" : "circle",
                             accessibilityDescription: nil)
        img?.isTemplate = true
        button.image = img
        button.toolTip = disabled ? "Lidiculous · Built-in OFF" : "Lidiculous"
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 260)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            guard let button = statusItem.button else { return }
            var anchor = button.bounds
            anchor.origin.y = 0
            anchor.size.height = 0
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.popover.isShown else { return }
                self.popover.performClose(nil)
            }
        }
    }
}
