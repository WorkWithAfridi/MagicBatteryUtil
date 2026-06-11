//
//  DashboardView.swift
//  MagicBatteryUtil
//

import SwiftUI
import UserNotifications

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroPanel
                    header
                    statusStack

                    if appModel.devices.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(appModel.devices) { device in
                                DeviceCardView(device: device)
                                    .environmentObject(appModel)
                            }
                        }
                    }

                    helpSection
                }
                .padding(24)
            }
            .background(AppTheme.pageGradient)
            .navigationTitle("Magic Battery Monitor")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        openSettingsWindow()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        .task {
            await appModel.refresh(reason: .dashboardAppear)
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MagicBatteryUtil")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("A focused battery dashboard for your Apple Magic accessories.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(lastUpdatedText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(status: appModel.lowBatteryCount > 0 ? .low : .good)
                }
            }

            HStack(spacing: 24) {
                StatBlock(value: "\(appModel.connectedDevicesCount)", label: "Connected")
                StatBlock(value: "\(appModel.lowBatteryCount)", label: "Need attention")
                StatBlock(value: appModel.averageBatteryPercent.map { "\($0)%" } ?? "N/A", label: "Average charge")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: AppTheme.shadowColor, radius: 20, y: 14)
    }

    private var header: some View {
        HStack {
            Text("Devices")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            HStack(spacing: 10) {
                if appModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.low)
                }
                Text("Alert threshold: \(appModel.thresholdPercent)%")
            }
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var statusStack: some View {
        if appModel.notificationAuthorizationStatus != .authorized {
            permissionBanner
        }

        if let errorMessage = appModel.errorMessage {
            statusBanner(title: "We couldn't update your latest battery status", message: errorMessage)
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications are not fully enabled")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text("Low-battery alerts need notification permission. You can request access now or open System Settings.")
                .foregroundStyle(AppTheme.secondaryText)
            HStack {
                Button("Request Permission") {
                    Task { await appModel.requestNotificationPermission() }
                }
                .buttonStyle(.borderedProminent)
                Button("Open Notification Settings") {
                    appModel.openNotificationSettings()
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }

    private func statusBanner(title: String, message: String, tint: Color = AppTheme.critical) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text(message)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No supported Magic devices detected")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Turn on your Magic Keyboard, Magic Mouse, or Magic Trackpad and make sure it is paired with this Mac. Your accessories will appear here as soon as they are available.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .glassPanel()
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Helpful tips")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text("If an accessory does not appear, reconnect it, confirm Bluetooth is enabled, and give the app a moment to pick up the latest status.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 4)
        .padding(18)
        .glassPanel()
    }

    private var lastUpdatedText: String {
        guard let lastSuccessfulRefreshAt = appModel.lastSuccessfulRefreshAt else {
            return "Preparing your latest battery status"
        }
        return "Last updated \(lastSuccessfulRefreshAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}

struct DeviceCardView: View {
    @EnvironmentObject private var appModel: AppModel
    let device: DeviceBatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Label(device.displayName, systemImage: device.kind.symbolName)
                    .font(.headline)
                Spacer()
                StatusPill(status: displayStatus)
            }

        HStack(alignment: .lastTextBaseline) {
            Text(device.batteryLabel)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
            Text(device.kind.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }

            BatteryLevelBar(percent: device.batteryPercent, color: statusColor)

            HStack(spacing: 10) {
                detailPill(title: connectionLabel, color: connectionColor)
                detailPill(title: displayStatus.title, color: statusColor)
                detailPill(title: device.kind.displayName, color: AppTheme.neutral)
            }

            VStack(alignment: .leading, spacing: 6) {
                row(title: "Battery level", value: batteryDescription)
                row(title: "Connection", value: connectionLabel)
                row(title: "Last updated", value: device.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                if let serialNumber = device.serialNumber {
                    row(title: "Identifier", value: serialNumber)
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)

            if let supportMessage {
                Text(supportMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.tertiaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statusColor: Color {
        displayStatus.color
    }

    private var displayStatus: BatteryDisplayStatus {
        device.displayStatus(threshold: appModel.thresholdPercent, staleInterval: appModel.staleInterval)
    }

    private var connectionLabel: String {
        device.connectionState.rawValue.capitalized
    }

    private var connectionColor: Color {
        device.connectionState == .connected ? AppTheme.good : AppTheme.neutral
    }

    private var batteryDescription: String {
        guard let batteryPercent = device.batteryPercent else {
            return "Currently unavailable"
        }

        switch displayStatus {
        case .critical:
            return "\(batteryPercent)% • Charge soon"
        case .low:
            return "\(batteryPercent)% • Below alert level"
        case .stale:
            return "\(batteryPercent)% • Waiting for a fresh update"
        case .disconnected:
            return "\(batteryPercent)% • Last known level"
        case .unknown:
            return "\(batteryPercent)%"
        case .good:
            return "\(batteryPercent)% • Looking good"
        }
    }

    private var supportMessage: String? {
        switch displayStatus {
        case .critical:
            return "This accessory is critically low and should be charged as soon as possible."
        case .low:
            return "This accessory is below your alert threshold."
        case .stale:
            return "Bring this accessory online to refresh its current battery level."
        case .disconnected:
            return "Reconnect this accessory to update its live battery status."
        case .good, .unknown:
            return nil
        }
    }

    private func detailPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
    }
}
