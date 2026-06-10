//
//  SettingsView.swift
//  MagicBatteryUtil
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @SceneStorage("settings.selectedRoute") private var selectedRouteRawValue = SettingsRoute.overview.rawValue

    private var selectedRoute: SettingsRoute {
        get { SettingsRoute(rawValue: selectedRouteRawValue) ?? .overview }
        nonmutating set { selectedRouteRawValue = newValue.rawValue }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { selectedRoute },
                set: { selectedRoute = $0 ?? .overview }
            )) {
                ForEach(SettingsRoute.allCases) { route in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.title)
                            Text(route.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } icon: {
                        Image(systemName: route.symbolName)
                    }
                    .tag(route)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageGradient)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsHeader
                    detailContent(for: selectedRoute)
                }
                .padding(24)
            }
            .background(AppTheme.pageGradient)
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedRoute.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
            Text(selectedRoute.subtitle)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func detailContent(for route: SettingsRoute) -> some View {
        switch route {
        case .overview:
            overviewPage
        case .notifications:
            notificationsPage
        case .startup:
            startupPage
        case .monitoring:
            monitoringPage
        case .support:
            supportPage
        }
    }

    private var overviewPage: some View {
        Group {
            settingsSection("Experience") {
                settingsRow(title: "Appearance", value: "Dark mode only")
                settingsRow(title: "Auto-refresh", value: "Every 1 minute")
                settingsRow(title: "Current alert threshold", value: "\(appModel.thresholdPercent)%")
                settingsRow(title: "Connected devices", value: "\(appModel.connectedDevicesCount)")
            }

            settingsSection("Current status") {
                settingsRow(title: "Notifications", value: authorizationLabel)
                settingsRow(title: "Launch at login", value: launchAtLoginSummary)
                settingsRow(title: "Latest refresh", value: lastRefreshSummary)
            }
        }
    }

    private var notificationsPage: some View {
        Group {
            settingsSection("Alert rules") {
                Toggle("Enable low-battery alerts", isOn: $appModel.notificationsEnabled)
                    .toggleStyle(.switch)

                HStack {
                    Text("Low-battery threshold")
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Stepper(value: $appModel.thresholdPercent, in: 5...80, step: 5) {
                        Text("\(appModel.thresholdPercent)%")
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .frame(width: 120)
                }
            }

            settingsSection("Permission status") {
                settingsRow(title: "Authorization", value: authorizationLabel)
                Text(notificationHelpText)
                    .foregroundStyle(AppTheme.secondaryText)

                HStack {
                    Button("Request Notification Permission") {
                        Task { await appModel.requestNotificationPermission() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Notification Settings") {
                        appModel.openNotificationSettings()
                    }
                }
            }
        }
    }

    private var startupPage: some View {
        Group {
            settingsSection("Launch behavior") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { appModel.launchAtLoginEnabled },
                        set: { appModel.setLaunchAtLogin($0) }
                    )
                )

                settingsRow(title: "Current status", value: launchAtLoginSummary)

                if let launchAtLoginError = appModel.launchAtLoginError {
                    Text(launchAtLoginError)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Enable this to keep MagicBatteryUtil monitoring your devices after you sign in.")
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var monitoringPage: some View {
        Group {
            settingsSection("Monitoring engine") {
                settingsRow(title: "Polling interval", value: "1 minute")
                settingsRow(title: "Refresh triggers", value: "Launch, wake, and timer")
                settingsRow(title: "Data source", value: "IORegistry (`ioreg`)")
                Text("Manual refresh has been removed. The app refreshes automatically on launch, after wake, and every minute while running.")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            settingsSection("Shared state") {
                Text("Battery snapshots are cached for menu bar updates now and for the future WidgetKit extension target.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var supportPage: some View {
        Group {
            settingsSection("Troubleshooting") {
                Text("If a device does not appear, reconnect it, confirm Bluetooth pairing, and give the app up to one minute to pick up the next refresh cycle.")
                    .foregroundStyle(AppTheme.secondaryText)

                if let diagnosticsMessage = appModel.diagnosticsMessage {
                    Text(diagnosticsMessage)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                HStack {
                    Button("Open Bluetooth Settings") {
                        openSystemSettingsPane("x-apple.systempreferences:com.apple.Bluetooth")
                    }
                    Button("Open Notifications Settings") {
                        appModel.openNotificationSettings()
                    }
                }
            }

            settingsSection("Project status") {
                Text("The next major milestone is automated tests and a WidgetKit extension target for cached battery widgets.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var authorizationLabel: String {
        switch appModel.notificationAuthorizationStatus {
        case .authorized, .provisional:
            return "Enabled"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationHelpText: String {
        switch appModel.notificationAuthorizationStatus {
        case .authorized, .provisional:
            return "Low-battery alerts are available and will be sent only when a device crosses below your threshold."
        case .denied:
            return "Notifications are currently denied. Open System Settings if you want low-battery alerts to work again."
        case .notDetermined:
            return "Notifications have not been requested yet. Ask for permission here when you are ready."
        @unknown default:
            return "Notification authorization is in an unknown state."
        }
    }

    private var launchAtLoginSummary: String {
        appModel.launchAtLoginEnabled ? "Enabled" : "Disabled"
    }

    private var lastRefreshSummary: String {
        guard let lastSuccessfulRefreshAt = appModel.lastSuccessfulRefreshAt else {
            return "No successful refresh yet"
        }
        return lastSuccessfulRefreshAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
