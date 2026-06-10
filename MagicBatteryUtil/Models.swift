//
//  Models.swift
//  MagicBatteryUtil
//

import Foundation

enum DeviceKind: String, Codable, CaseIterable {
    case keyboard
    case mouse
    case trackpad
    case unknown

    var displayName: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .mouse:
            return "Mouse"
        case .trackpad:
            return "Trackpad"
        case .unknown:
            return "Accessory"
        }
    }

    var symbolName: String {
        switch self {
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "computermouse"
        case .trackpad:
            return "rectangle.and.hand.point.up.left"
        case .unknown:
            return "battery.100"
        }
    }
}

enum ConnectionState: String, Codable {
    case connected
    case disconnected
}

enum BatteryDataSource: String, Codable {
    case ioRegistry
    case cached
    case mock
}

enum RefreshReason: String, Codable {
    case appLaunch
    case dashboardAppear
    case manual
    case scheduledPoll
    case wakeFromSleep
}

struct DeviceBatterySnapshot: Codable, Identifiable, Equatable {
    var id: String
    var productName: String
    var kind: DeviceKind
    var batteryPercent: Int?
    var connectionState: ConnectionState
    var lastSeenAt: Date
    var source: BatteryDataSource
    var productID: Int?
    var serialNumber: String?

    var displayName: String {
        productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? kind.displayName : productName
    }

    var batteryLabel: String {
        guard let batteryPercent else { return "Unknown" }
        return "\(batteryPercent)%"
    }

    func isLow(threshold: Int) -> Bool {
        guard connectionState == .connected, let batteryPercent else { return false }
        return batteryPercent < threshold
    }

    func status(threshold: Int, staleInterval: TimeInterval, now: Date = .now) -> String {
        if now.timeIntervalSince(lastSeenAt) > staleInterval {
            return "Stale"
        }
        if connectionState == .disconnected {
            return "Disconnected"
        }
        guard let batteryPercent else {
            return "Unknown"
        }
        if batteryPercent < min(10, threshold) {
            return "Critical"
        }
        if batteryPercent < threshold {
            return "Low"
        }
        return "Good"
    }
}

struct BatterySnapshotEnvelope: Codable {
    var generatedAt: Date
    var devices: [DeviceBatterySnapshot]
    var thresholdPercent: Int
}

struct NotificationMemory: Codable {
    var deviceID: String
    var lastNotifiedAt: Date?
    var wasBelowThreshold: Bool
}

struct MonitorState {
    var devices: [DeviceBatterySnapshot]
    var lastRefreshAt: Date?
    var lastSuccessfulRefreshAt: Date?
    var isRefreshing: Bool
    var errorMessage: String?
}

extension Array where Element == DeviceBatterySnapshot {
    var sortedForDisplay: [DeviceBatterySnapshot] {
        sorted {
            if $0.kind == $1.kind {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return sortIndex(for: $0.kind) < sortIndex(for: $1.kind)
        }
    }

    private func sortIndex(for kind: DeviceKind) -> Int {
        switch kind {
        case .keyboard:
            return 0
        case .mouse:
            return 1
        case .trackpad:
            return 2
        case .unknown:
            return 3
        }
    }
}
