//
//  SharedBatteryStore.swift
//  MagicBatteryUtil
//

import Foundation

enum SharedStoreAccessStatus: Equatable {
    case appGroupAvailable
    case appGroupUnavailable

    var title: String {
        switch self {
        case .appGroupAvailable:
            return "App Group connected"
        case .appGroupUnavailable:
            return "App Group unavailable"
        }
    }

    var detail: String {
        switch self {
        case .appGroupAvailable:
            return "The app can publish widget snapshots into the shared container."
        case .appGroupUnavailable:
            return "The app is using local cache only, so widgets cannot read live battery snapshots yet."
        }
    }
}

protocol SharedBatteryStoreProtocol {
    func loadSnapshotEnvelope() -> BatterySnapshotEnvelope?
    var accessStatus: SharedStoreAccessStatus { get }
}

final class SharedBatteryStore: SharedBatteryStoreProtocol {
    private enum Keys {
        static let latestSnapshot = "shared.latestSnapshot"
        static let notificationMemory = "shared.notificationMemory"
    }

    private let localDefaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private let appGroupContainerURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var accessStatus: SharedStoreAccessStatus {
        (sharedDefaults != nil && appGroupContainerURL != nil) ? .appGroupAvailable : .appGroupUnavailable
    }

    init(appGroupID: String = AppConfiguration.appGroupID) {
        localDefaults = .standard
        sharedDefaults = UserDefaults(suiteName: appGroupID)
        appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    func saveSnapshotEnvelope(_ envelope: BatterySnapshotEnvelope) {
        guard let data = try? encoder.encode(envelope) else { return }
        localDefaults.set(data, forKey: Keys.latestSnapshot)
        sharedDefaults?.set(data, forKey: Keys.latestSnapshot)
        if let snapshotFileURL {
            try? data.write(to: snapshotFileURL, options: .atomic)
        }
    }

    func loadSnapshotEnvelope() -> BatterySnapshotEnvelope? {
        let data = loadSharedSnapshotData() ?? localDefaults.data(forKey: Keys.latestSnapshot)
        guard let data else { return nil }
        return try? decoder.decode(BatterySnapshotEnvelope.self, from: data)
    }

    func loadNotificationMemory() -> [String: NotificationMemory] {
        let data = sharedDefaults?.data(forKey: Keys.notificationMemory) ?? localDefaults.data(forKey: Keys.notificationMemory)
        guard let data,
              let memories = try? decoder.decode([NotificationMemory].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: memories.map { ($0.deviceID, $0) })
    }

    func saveNotificationMemory(_ memory: [String: NotificationMemory]) {
        let payload = Array(memory.values)
        guard let data = try? encoder.encode(payload) else { return }
        localDefaults.set(data, forKey: Keys.notificationMemory)
        sharedDefaults?.set(data, forKey: Keys.notificationMemory)
    }

    private var snapshotFileURL: URL? {
        appGroupContainerURL?.appendingPathComponent(AppConfiguration.widgetSnapshotFilename)
    }

    private func loadSharedSnapshotData() -> Data? {
        if let snapshotFileURL,
           let data = try? Data(contentsOf: snapshotFileURL) {
            return data
        }
        return sharedDefaults?.data(forKey: Keys.latestSnapshot)
    }
}
