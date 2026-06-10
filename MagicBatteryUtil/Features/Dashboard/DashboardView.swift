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

                    troubleshootingSection
                }
                .padding(24)
            }
            .background(AppTheme.pageGradient)
            .navigationTitle("Magic Battery Monitor")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        openWindow(id: "main")
                    } label: {
                        Label("Open Window", systemImage: "macwindow")
                    }

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
                    Text("Auto-refresh every minute")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
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
            statusBanner(title: "Last refresh failed", message: errorMessage)
        }

        if let diagnosticsMessage = appModel.diagnosticsMessage {
            statusBanner(title: "Device diagnostics", message: diagnosticsMessage, tint: AppTheme.neutral)
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
            Text("Turn your Magic Keyboard, Magic Mouse, or Magic Trackpad on, make sure it is paired to this Mac, then wait up to a minute for the next refresh cycle.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .glassPanel()
    }

    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Troubleshooting")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text("This app reads battery data from macOS IORegistry. If a device does not appear, reconnect it, toggle Bluetooth, or wake the Mac and refresh again.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 4)
        .padding(18)
        .glassPanel()
    }

    private var lastUpdatedText: String {
        guard let lastSuccessfulRefreshAt = appModel.lastSuccessfulRefreshAt else {
            return "No successful refresh yet"
        }
        return "Last updated \(lastSuccessfulRefreshAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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

            VStack(alignment: .leading, spacing: 6) {
                row(title: "Connection", value: device.connectionState.rawValue.capitalized)
                row(title: "Last seen", value: device.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                if let serialNumber = device.serialNumber {
                    row(title: "Identifier", value: serialNumber)
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
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
}
