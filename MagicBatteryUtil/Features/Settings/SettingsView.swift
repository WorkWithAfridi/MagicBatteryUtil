//
//  SettingsView.swift
//  MagicBatteryUtil
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Tune alerts, startup behavior, and the always-on monitoring behavior for MagicBatteryUtil.")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.bottom, 4)

                settingsSection("Overview") {
                    settingsRow(title: "Appearance", value: "Dark mode only")
                    settingsRow(title: "Auto-refresh", value: "Every 1 minute")
                    settingsRow(title: "Current alert threshold", value: "\(appModel.thresholdPercent)%")
                }

                settingsSection("Notifications") {
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

                    HStack {
                        Text("Authorization")
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text(authorizationLabel)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

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

                settingsSection("Startup") {
                    Toggle(
                        "Launch at Login",
                        isOn: Binding(
                            get: { appModel.launchAtLoginEnabled },
                            set: { appModel.setLaunchAtLogin($0) }
                        )
                    )

                    if let launchAtLoginError = appModel.launchAtLoginError {
                        Text(launchAtLoginError)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                settingsSection("Monitoring") {
                    settingsRow(title: "Polling interval", value: "1 minute")
                    LabeledContent("Data source", value: "IORegistry (`ioreg`)")
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Manual refresh has been removed. The app refreshes automatically on launch, after wake, and every minute while running.")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Widgets are designed to read cached data from a shared store, but the WidgetKit extension target still needs to be added before the checklist's widget phase is complete.")
                        .foregroundStyle(AppTheme.secondaryText)
                }

                settingsSection("Supported devices") {
                    Text("Magic Keyboard, Magic Mouse, and Magic Trackpad. If a device does not appear, reconnect it and refresh after wake.")
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .padding(24)
        }
        .background(AppTheme.pageGradient)
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
}
