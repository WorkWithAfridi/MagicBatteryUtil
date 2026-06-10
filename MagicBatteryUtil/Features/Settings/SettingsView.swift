//
//  SettingsView.swift
//  MagicBatteryUtil
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable low-battery alerts", isOn: $appModel.notificationsEnabled)

                HStack {
                    Text("Low-battery threshold")
                    Spacer()
                    Stepper(value: $appModel.thresholdPercent, in: 5...80, step: 5) {
                        Text("\(appModel.thresholdPercent)%")
                    }
                    .frame(width: 120)
                }

                HStack {
                    Text("Authorization")
                    Spacer()
                    Text(authorizationLabel)
                        .foregroundStyle(.secondary)
                }

                Button("Request Notification Permission") {
                    Task { await appModel.requestNotificationPermission() }
                }

                Button("Open Notification Settings") {
                    appModel.openNotificationSettings()
                }
            }

            Section("Startup") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { appModel.launchAtLoginEnabled },
                        set: { appModel.setLaunchAtLogin($0) }
                    )
                )

                if let launchAtLoginError = appModel.launchAtLoginError {
                    Text(launchAtLoginError)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Monitoring") {
                LabeledContent("Polling interval", value: "10 minutes")
                LabeledContent("Data source", value: "IORegistry (`ioreg`)")
                Text("Widgets are designed to read cached data from a shared store, but the WidgetKit extension target still needs to be added before the checklist's widget phase is complete.")
                    .foregroundStyle(.secondary)
            }

            Section("Supported devices") {
                Text("Magic Keyboard, Magic Mouse, and Magic Trackpad. If a device does not appear, reconnect it and refresh after wake.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
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
}
