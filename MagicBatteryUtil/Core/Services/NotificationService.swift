//
//  NotificationService.swift
//  MagicBatteryUtil
//

import AppKit
import Foundation
import UserNotifications

final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func sendLowBatteryNotification(for device: DeviceBatterySnapshot) async {
        guard let percent = device.batteryPercent else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(device.displayName) battery is low"
        content.body = "Current charge is \(percent)%."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-battery-\(device.id)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
