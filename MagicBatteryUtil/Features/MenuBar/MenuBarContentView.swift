//
//  MenuBarContentView.swift
//  MagicBatteryUtil
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Magic Battery")
                .font(.headline)

            if appModel.devices.isEmpty {
                Text("No supported devices detected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.devices.prefix(4)) { device in
                    HStack {
                        Label(device.displayName, systemImage: device.kind.symbolName)
                            .lineLimit(1)
                        Spacer()
                        Text(device.batteryLabel)
                            .foregroundStyle(device.isLow(threshold: appModel.thresholdPercent) ? .orange : .primary)
                    }
                    .font(.subheadline)
                }
            }

            Divider()

            Button("Refresh Now") {
                Task { await appModel.refresh() }
            }

            Button("Open App") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Settings") {
                openSettingsWindow()
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(16)
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
