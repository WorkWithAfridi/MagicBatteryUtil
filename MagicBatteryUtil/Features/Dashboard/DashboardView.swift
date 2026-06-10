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
                    header

                    if appModel.notificationAuthorizationStatus != .authorized {
                        permissionBanner
                    }

                    if let errorMessage = appModel.errorMessage {
                        statusBanner(title: "Last refresh failed", message: errorMessage)
                    }

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
            .navigationTitle("Magic Battery Monitor")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        Task { await appModel.refresh() }
                    } label: {
                        if appModel.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .help("Refresh battery data now")

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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live accessory battery levels for your Apple Magic devices.")
                .font(.title2.weight(.semibold))

            HStack(spacing: 16) {
                Text(lastUpdatedText)
                    .foregroundStyle(.secondary)
                Text("Low-battery threshold: \(appModel.thresholdPercent)%")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications are not fully enabled")
                .font(.headline)
            Text("Low-battery alerts need notification permission. You can request access now or open System Settings.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Request Permission") {
                    Task { await appModel.requestNotificationPermission() }
                }
                Button("Open Notification Settings") {
                    appModel.openNotificationSettings()
                }
            }
        }
        .padding()
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusBanner(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No supported Magic devices detected")
                .font(.title3.weight(.semibold))
            Text("Turn your Magic Keyboard, Magic Mouse, or Magic Trackpad on, make sure it is paired to this Mac, then refresh.")
                .foregroundStyle(.secondary)
            Button("Refresh Again") {
                Task { await appModel.refresh() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
    }

    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Troubleshooting")
                .font(.headline)
            Text("This app reads battery data from macOS IORegistry. If a device does not appear, reconnect it, toggle Bluetooth, or wake the Mac and refresh again.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
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
                Text(device.status(threshold: appModel.thresholdPercent, staleInterval: appModel.staleInterval))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            Text(device.batteryLabel)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            ProgressView(value: Double(device.batteryPercent ?? 0), total: 100)
                .tint(statusColor)

            VStack(alignment: .leading, spacing: 6) {
                row(title: "Connection", value: device.connectionState.rawValue.capitalized)
                row(title: "Last seen", value: device.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                if let serialNumber = device.serialNumber {
                    row(title: "Identifier", value: serialNumber)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statusColor: Color {
        switch device.status(threshold: appModel.thresholdPercent, staleInterval: appModel.staleInterval) {
        case "Critical":
            return .red
        case "Low":
            return .orange
        case "Disconnected", "Stale":
            return .secondary
        default:
            return .green
        }
    }
}
