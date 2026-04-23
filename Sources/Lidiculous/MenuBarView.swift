// Lidiculous
// Copyright © 2025 @ciutadellla. All rights reserved.

import SwiftUI

private extension Color {
    static let lidRose = Color(red: 0.65, green: 0.25, blue: 0.38)
    static let lidTeal = Color(red: 0.24, green: 0.60, blue: 0.60)
    static let lidDim  = Color(red: 0.62, green: 0.45, blue: 0.52)
}

struct MenuBarView: View {
    @ObservedObject private var mgr = DisplayManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.lidRose.opacity(0.18))
            displayList
            if let err = mgr.lastError { errorBanner(err) }
            Divider().overlay(Color.lidRose.opacity(0.18))
            autoToggleRow
            Divider().overlay(Color.lidRose.opacity(0.18))
            launchAtLoginRow
            Divider().overlay(Color.lidRose.opacity(0.18))
            footer
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "display.2")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.lidRose)
            Text("Lidiculous")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.lidRose)
            Spacer()
            Button { mgr.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.lidDim)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var displayList: some View {
        VStack(spacing: 0) {
            ForEach(mgr.displays) { info in
                DisplayRow(info: info)
                if info.id != mgr.displays.last?.id {
                    Divider().padding(.leading, 14).overlay(Color.lidRose.opacity(0.12))
                }
            }
        }
    }

    private var autoToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.horizontal")
                .font(.system(size: 13))
                .foregroundColor(mgr.autoToggleEnabled ? .lidRose : .lidDim)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-toggle built-in")
                    .font(.system(size: 12, weight: .medium))
                Text(mgr.autoToggleEnabled
                     ? "Disables on HDMI connect · Re-enables on disconnect"
                     : "Manual control only")
                    .font(.system(size: 10))
                    .foregroundColor(.lidDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $mgr.autoToggleEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.lidRose)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .animation(.easeInOut(duration: 0.15), value: mgr.autoToggleEnabled)
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "power")
                .font(.system(size: 13))
                .foregroundColor(mgr.launchAtLogin ? .lidRose : .lidDim)
                .frame(width: 20)
            Text("Launch at Login")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Toggle("", isOn: $mgr.launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.lidRose)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .animation(.easeInOut(duration: 0.15), value: mgr.launchAtLogin)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.lidRose).font(.system(size: 12))
            Text(msg).font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { mgr.lastError = nil } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }.buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.lidRose.opacity(0.10))
    }

    private var footer: some View {
        HStack {
            Button("Re-enable All") { mgr.enableAll() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.lidDim)
                .help("Force all displays back on")
            Spacer()
            Button("Quit") {
                (NSApp.delegate as? AppDelegate)?.quit()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.lidDim)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

struct DisplayRow: View {
    let info: DisplayInfo
    @ObservedObject private var mgr = DisplayManager.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconBg)
                    .frame(width: 34, height: 34)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconFg)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(info.isDisabled ? Color.lidDim : Color.lidTeal)
                        .frame(width: 6, height: 6)
                    Text(info.isDisabled ? "Disabled" : "Active")
                        .font(.system(size: 10))
                        .foregroundColor(info.isDisabled ? .lidDim : .lidTeal)
                    Text("·").foregroundColor(.lidDim).font(.system(size: 10))
                    Text("\(Int(info.bounds.width)) × \(Int(info.bounds.height))")
                        .font(.system(size: 10)).foregroundColor(.lidDim)
                }
            }
            Spacer()
            if info.isBuiltin {
                Toggle("", isOn: Binding(get: { !info.isDisabled },
                                         set: { _ in mgr.toggleBuiltin() }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.lidTeal)
            } else {
                Text(info.isDisabled ? "Off" : "On")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(
                        info.isDisabled
                            ? Color.lidDim.opacity(0.2)
                            : Color.lidRose.opacity(0.18)
                    ))
                    .foregroundColor(info.isDisabled ? .lidDim : .lidRose)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(hovering ? Color.lidRose.opacity(0.06) : Color.clear)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: info.isDisabled)
    }

    private var iconName: String {
        info.isBuiltin
            ? (info.isDisabled ? "laptopcomputer.slash" : "laptopcomputer")
            : (info.isDisabled ? "display.slash" : "display")
    }
    private var iconBg: Color {
        info.isDisabled
            ? Color.lidDim.opacity(0.12)
            : (info.isBuiltin ? Color.lidTeal.opacity(0.14) : Color.lidRose.opacity(0.14))
    }
    private var iconFg: Color {
        info.isDisabled ? .lidDim : (info.isBuiltin ? .lidTeal : .lidRose)
    }
}
