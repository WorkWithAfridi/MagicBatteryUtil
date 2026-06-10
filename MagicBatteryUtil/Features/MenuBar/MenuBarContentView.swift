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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MagicBatteryUtil")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(appModel.connectedDevicesCount) connected")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                StatusPill(status: appModel.lowBatteryCount > 0 ? .low : .good)
            }

            if appModel.devices.isEmpty {
                Text("No supported devices detected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.devices.prefix(4)) { device in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(device.displayName, systemImage: device.kind.symbolName)
                                .lineLimit(1)
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Text(device.batteryLabel)
                                .foregroundStyle(device.isLow(threshold: appModel.thresholdPercent) ? AppTheme.low : AppTheme.primaryText)
                        }
                        BatteryLevelBar(percent: device.batteryPercent, color: device.displayStatus(threshold: appModel.thresholdPercent, staleInterval: appModel.staleInterval).color)
                    }
                    .padding(.vertical, 2)
                    .font(.subheadline)
                }
            }

            if let errorMessage = appModel.errorMessage {
                Divider()
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.critical)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Open App") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Spacer()

                if appModel.isRefreshing {
                    Label("Refreshing", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Updates every minute")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            HStack {
                Button("Settings") {
                    openSettingsWindow()
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.panelFill)
        )
    }

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }
}
