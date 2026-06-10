//
//  BatteryMonitorService.swift
//  MagicBatteryUtil
//

import Foundation
import WidgetKit

@MainActor
final class BatteryMonitorService {
    var onStateChange: ((MonitorState) -> Void)?

    private let reader: any BatteryReader
    private let settingsStore: SettingsStore
    private let notificationService: NotificationService
    private let sharedStore: SharedBatteryStore
    private var timer: Timer?
    private var deviceCache: [String: DeviceBatterySnapshot] = [:]
    private var lastSuccessfulRefreshAt: Date?
    private var isRefreshing = false
    private var lastWidgetReloadAt: Date?
    private var diagnosticsMessage: String?

    init(
        reader: any BatteryReader,
        settingsStore: SettingsStore,
        notificationService: NotificationService,
        sharedStore: SharedBatteryStore
    ) {
        self.reader = reader
        self.settingsStore = settingsStore
        self.notificationService = notificationService
        self.sharedStore = sharedStore

        if let cached = sharedStore.loadSnapshotEnvelope() {
            deviceCache = Dictionary(uniqueKeysWithValues: cached.devices.map { ($0.id, $0) })
            lastSuccessfulRefreshAt = cached.generatedAt
        }
    }

    func start() {
        schedulePolling()
        Task { await refresh(reason: .appLaunch) }
    }

    func refresh(reason: RefreshReason) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let refreshStartedAt = Date()
        var latestErrorMessage: String?
        publishState(lastRefreshAt: refreshStartedAt, errorMessage: nil)

        defer {
            isRefreshing = false
            publishState(lastRefreshAt: refreshStartedAt, errorMessage: latestErrorMessage)
        }

        do {
            let readResult = try readDevices()
            diagnosticsMessage = readResult.diagnostics.nilIfEmpty()?.joined(separator: "\n")
            let freshDevices = readResult.devices
            let mergedDevices = mergeWithDisconnectedDevices(freshDevices)
            deviceCache = Dictionary(uniqueKeysWithValues: mergedDevices.map { ($0.id, $0) })

            lastSuccessfulRefreshAt = Date()
            let envelope = BatterySnapshotEnvelope(
                generatedAt: lastSuccessfulRefreshAt ?? .now,
                devices: mergedDevices,
                thresholdPercent: settingsStore.thresholdPercent
            )
            sharedStore.saveSnapshotEnvelope(envelope)
            reloadWidgetsIfNeeded()

            await evaluateNotifications(for: mergedDevices, threshold: settingsStore.thresholdPercent)
        } catch {
            latestErrorMessage = error.localizedDescription
        }
    }

    private func readDevices() throws -> BatteryReadResult {
        if let reader = reader as? IORegistryBatteryReader {
            return try reader.readBatteryResult()
        }
        return BatteryReadResult(devices: try reader.readBatterySnapshots(), diagnostics: [])
    }

    private func schedulePolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh(reason: .scheduledPoll)
            }
        }
    }

    private func mergeWithDisconnectedDevices(_ freshDevices: [DeviceBatterySnapshot]) -> [DeviceBatterySnapshot] {
        let incoming = Dictionary(uniqueKeysWithValues: freshDevices.map { ($0.id, $0) })
        let disconnected = deviceCache.values.compactMap { existing -> DeviceBatterySnapshot? in
            guard incoming[existing.id] == nil else { return nil }
            var stale = existing
            stale.connectionState = .disconnected
            stale.source = .cached
            return stale
        }

        return freshDevices + disconnected
    }

    private func evaluateNotifications(for devices: [DeviceBatterySnapshot], threshold: Int) async {
        var memory = sharedStore.loadNotificationMemory()
        let notificationsEnabled = settingsStore.notificationsEnabled

        for device in devices {
            let previous = memory[device.id] ?? NotificationMemory(deviceID: device.id, lastNotifiedAt: nil, wasBelowThreshold: false)
            let isBelow = device.isLow(threshold: threshold)

            if notificationsEnabled && !previous.wasBelowThreshold && isBelow {
                await notificationService.sendLowBatteryNotification(for: device)
                memory[device.id] = NotificationMemory(deviceID: device.id, lastNotifiedAt: .now, wasBelowThreshold: true)
            } else {
                memory[device.id] = NotificationMemory(
                    deviceID: device.id,
                    lastNotifiedAt: previous.lastNotifiedAt,
                    wasBelowThreshold: isBelow
                )
            }
        }

        sharedStore.saveNotificationMemory(memory)
    }

    private func reloadWidgetsIfNeeded() {
        let now = Date()
        if let lastWidgetReloadAt, now.timeIntervalSince(lastWidgetReloadAt) < 45 {
            return
        }
        lastWidgetReloadAt = now
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func publishState(lastRefreshAt: Date?, errorMessage: String?) {
        onStateChange?(
            MonitorState(
                devices: Array(deviceCache.values),
                lastRefreshAt: lastRefreshAt,
                lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
                isRefreshing: isRefreshing,
                errorMessage: errorMessage,
                diagnosticsMessage: diagnosticsMessage
            )
        )
    }
}

private extension Array where Element == String {
    func nilIfEmpty() -> [String]? {
        isEmpty ? nil : self
    }
}
