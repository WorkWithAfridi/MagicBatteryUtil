//
//  SettingsRoute.swift
//  MagicBatteryUtil
//

import Foundation

enum SettingsRoute: String, CaseIterable, Identifiable {
    case overview
    case notifications
    case startup
    case monitoring
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .notifications:
            return "Notifications"
        case .startup:
            return "Startup"
        case .monitoring:
            return "Monitoring"
        case .support:
            return "Support"
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .notifications:
            return "bell.badge"
        case .startup:
            return "power"
        case .monitoring:
            return "waveform.path.ecg"
        case .support:
            return "questionmark.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "Core app behavior"
        case .notifications:
            return "Alerts and thresholds"
        case .startup:
            return "Launch at login"
        case .monitoring:
            return "Refresh and data flow"
        case .support:
            return "Troubleshooting"
        }
    }
}
