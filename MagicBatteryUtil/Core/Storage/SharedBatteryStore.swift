//
//  SharedBatteryStore.swift
//  MagicBatteryUtil
//

import Foundation

protocol SharedBatteryStoreProtocol {
    func loadSnapshotEnvelope() -> BatterySnapshotEnvelope?
}

final class SharedBatteryStore: SharedBatteryStoreProtocol {
    private enum Keys {
        static let latestSnapshot = "shared.latestSnapshot"
        static let notificationMemory = "shared.notificationMemory"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(appGroupID: String = AppConfiguration.appGroupID) {
        defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    }

    func saveSnapshotEnvelope(_ envelope: BatterySnapshotEnvelope) {
        guard let data = try? encoder.encode(envelope) else { return }
        defaults.set(data, forKey: Keys.latestSnapshot)
    }

    func loadSnapshotEnvelope() -> BatterySnapshotEnvelope? {
        guard let data = defaults.data(forKey: Keys.latestSnapshot) else { return nil }
        return try? decoder.decode(BatterySnapshotEnvelope.self, from: data)
    }

    func loadNotificationMemory() -> [String: NotificationMemory] {
        guard let data = defaults.data(forKey: Keys.notificationMemory),
              let memories = try? decoder.decode([NotificationMemory].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: memories.map { ($0.deviceID, $0) })
    }

    func saveNotificationMemory(_ memory: [String: NotificationMemory]) {
        let payload = Array(memory.values)
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: Keys.notificationMemory)
    }
}
