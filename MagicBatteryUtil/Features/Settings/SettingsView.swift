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
                settingsRow(title: "Low-battery alert", value: "\(appModel.thresholdPercent)%")
                settingsRow(title: "Connected devices", value: "\(appModel.connectedDevicesCount)")
            }

            settingsSection("Today") {
                settingsRow(title: "Notifications", value: authorizationLabel)
                settingsRow(title: "Launch at login", value: launchAtLoginSummary)
                settingsRow(title: "Last updated", value: lastRefreshSummary)
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

            settingsSection("Notification access") {
                settingsRow(title: "Status", value: authorizationLabel)
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

                settingsRow(title: "Status", value: launchAtLoginSummary)

                if let launchAtLoginError = appModel.launchAtLoginError {
                    Text(launchAtLoginError)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Enable this to keep MagicBatteryUtil ready as soon as you sign in.")
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var monitoringPage: some View {
        Group {
            settingsSection("Background updates") {
                settingsRow(title: "Update style", value: "Automatic")
                settingsRow(title: "Accessories", value: "Magic Keyboard, Mouse, and Trackpad")
                Text("MagicBatteryUtil keeps your latest accessory battery status current while the app is running.")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            settingsSection("Widgets") {
                settingsRow(title: "Status", value: appModel.sharedStoreAccessStatus.title)
                Text(appModel.sharedStoreAccessStatus.detail)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var supportPage: some View {
        Group {
            settingsSection("Getting help") {
                Text("If a device does not appear, reconnect it, confirm Bluetooth pairing, and give MagicBatteryUtil a moment to update its latest accessory status.")
                    .foregroundStyle(AppTheme.secondaryText)

                if appModel.sharedStoreAccessStatus == .appGroupUnavailable {
                    Text("If the widget looks empty, open MagicBatteryUtil once and it will sync your latest accessory status.")
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

            settingsSection("About the experience") {
                Text("MagicBatteryUtil is designed to keep your Magic accessory battery levels easy to check from the app, menu bar, and widget.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var authorizationLabel: String {
        switch appModel.notificationAuthorizationStatus {
        case .authorized, .provisional:
            return "Enabled"
        case .denied:
            return "Turned off"
        case .notDetermined:
            return "Not set up"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationHelpText: String {
        switch appModel.notificationAuthorizationStatus {
        case .authorized, .provisional:
            return "Low-battery alerts are available and will be sent only when a device crosses below your threshold."
        case .denied:
            return "Notifications are currently turned off. Open System Settings if you want low-battery alerts to work again."
        case .notDetermined:
            return "Notifications have not been set up yet. You can allow them here whenever you are ready."
        @unknown default:
            return "Notification authorization is in an unknown state."
        }
    }

    private var launchAtLoginSummary: String {
        appModel.launchAtLoginEnabled ? "Enabled" : "Disabled"
    }

    private var lastRefreshSummary: String {
        guard let lastSuccessfulRefreshAt = appModel.lastSuccessfulRefreshAt else {
            return "Preparing your latest battery status"
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
