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
                    HStack(spacing: 8) {
                        Text("MagicBatteryUtil")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Button {
                            openMainAndSettings()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Open MagicBatteryUtil settings")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(appModel.connectedDevicesCount) connected")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
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
                Text("Unable to update battery status right now. \(errorMessage)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.critical)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.panelFill)
        )
    }

    private func openMainAndSettings() {
        if !hasOpenMainWindow {
            openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows
            .filter(\.isVisible)
            .forEach { $0.orderFrontRegardless() }
        openWindow(id: "settings")
    }

    private var hasOpenMainWindow: Bool {
        NSApp.windows.contains { window in
            window.title == "Magic Battery Monitor" && window.isVisible
        }
    }
}
