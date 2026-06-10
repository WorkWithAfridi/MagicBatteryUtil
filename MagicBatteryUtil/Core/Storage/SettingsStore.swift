//
//  SettingsStore.swift
//  MagicBatteryUtil
//

import Foundation

final class SettingsStore {
    private enum Keys {
        static let thresholdPercent = "settings.thresholdPercent"
        static let notificationsEnabled = "settings.notificationsEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.thresholdPercent: 30,
            Keys.notificationsEnabled: true
        ])
    }

    var thresholdPercent: Int {
        get { defaults.integer(forKey: Keys.thresholdPercent) }
        set { defaults.set(max(5, min(80, newValue)), forKey: Keys.thresholdPercent) }
    }

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }
}
