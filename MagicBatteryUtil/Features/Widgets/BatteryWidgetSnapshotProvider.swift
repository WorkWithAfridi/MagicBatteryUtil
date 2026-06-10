//
//  BatteryWidgetSnapshotProvider.swift
//  MagicBatteryUtil
//

import Foundation

struct BatteryWidgetSnapshotState {
    let envelope: BatterySnapshotEnvelope?
    let generatedAt: Date?
    let isStale: Bool
    let staleMessage: String?
    let emptyMessage: String?

    static let empty = BatteryWidgetSnapshotState(
        envelope: nil,
        generatedAt: nil,
        isStale: true,
        staleMessage: nil,
        emptyMessage: "No battery snapshot is available yet."
    )
}

struct BatteryWidgetSnapshotProvider {
    private let store: SharedBatteryStoreProtocol

    init(store: SharedBatteryStoreProtocol = SharedBatteryStore()) {
        self.store = store
    }

    func loadState(now: Date = Date()) -> BatteryWidgetSnapshotState {
        guard let envelope = store.loadSnapshotEnvelope() else {
            return .empty
        }

        let isStale = now.timeIntervalSince(envelope.generatedAt) > AppConfiguration.widgetStaleInterval
        return BatteryWidgetSnapshotState(
            envelope: envelope,
            generatedAt: envelope.generatedAt,
            isStale: isStale,
            staleMessage: isStale ? "Cached data is older than 30 minutes." : nil,
            emptyMessage: envelope.devices.isEmpty ? "No supported devices were detected in the latest snapshot." : nil
        )
    }
}
