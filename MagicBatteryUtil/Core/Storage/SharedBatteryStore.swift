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
            return "Ready"
        case .appGroupUnavailable:
            return "Needs setup"
        }
    }

    var detail: String {
        switch self {
        case .appGroupAvailable:
            return "Your widget can show the latest battery status from MagicBatteryUtil."
        case .appGroupUnavailable:
            return "Open the latest app build once to finish syncing widget data."
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
        static let latestWidgetSnapshot = "shared.latestWidgetSnapshot"
        static let notificationMemory = "shared.notificationMemory"
    }

    private struct WidgetExportEnvelope: Codable {
        let generatedAt: Date
        let devices: [WidgetExportDevice]
        let thresholdPercent: Int
    }

    private struct WidgetExportDevice: Codable {
        let id: String
        let productName: String
        let kind: String
        let batteryPercent: Int?
        let connectionState: String
        let lastSeenAt: Date
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

        guard let widgetData = try? encoder.encode(exportEnvelope(from: envelope)) else { return }
        localDefaults.set(widgetData, forKey: Keys.latestWidgetSnapshot)
        sharedDefaults?.set(widgetData, forKey: Keys.latestWidgetSnapshot)
        if let widgetSnapshotFileURL {
            try? widgetData.write(to: widgetSnapshotFileURL, options: .atomic)
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

    private var widgetSnapshotFileURL: URL? {
        appGroupContainerURL?.appendingPathComponent(AppConfiguration.widgetExportFilename)
    }

    private func loadSharedSnapshotData() -> Data? {
        if let snapshotFileURL,
           let data = try? Data(contentsOf: snapshotFileURL) {
            return data
        }
        return sharedDefaults?.data(forKey: Keys.latestSnapshot)
    }

    private func exportEnvelope(from envelope: BatterySnapshotEnvelope) -> WidgetExportEnvelope {
        WidgetExportEnvelope(
            generatedAt: envelope.generatedAt,
            devices: envelope.devices.map {
                WidgetExportDevice(
                    id: $0.id,
                    productName: $0.productName,
                    kind: $0.kind.rawValue,
                    batteryPercent: $0.batteryPercent,
                    connectionState: $0.connectionState.rawValue,
                    lastSeenAt: $0.lastSeenAt
                )
            },
            thresholdPercent: envelope.thresholdPercent
        )
    }
}
