//
//  AppModel.swift
//  MagicBatteryUtil
//

import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var devices: [DeviceBatterySnapshot] = []
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var lastSuccessfulRefreshAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var diagnosticsMessage: String?
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginError: String?
    @Published var thresholdPercent: Int {
        didSet {
            let clampedValue = max(5, min(80, thresholdPercent))
            if clampedValue != thresholdPercent {
                thresholdPercent = clampedValue
                return
            }
            settingsStore.thresholdPercent = clampedValue
        }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            settingsStore.notificationsEnabled = notificationsEnabled
        }
    }

    let staleInterval: TimeInterval = 30 * 60

    var menuBarSymbolName: String {
        if devices.contains(where: { $0.displayStatus(threshold: thresholdPercent, staleInterval: staleInterval) == .critical }) {
            return "battery.0"
        }
        if devices.contains(where: { $0.isLow(threshold: thresholdPercent) }) {
            return "battery.25"
        }
        return "battery.75"
    }

    var connectedDevicesCount: Int {
        devices.filter { $0.connectionState == .connected }.count
    }

    var lowBatteryCount: Int {
        devices.filter { $0.isLow(threshold: thresholdPercent) }.count
    }

    var averageBatteryPercent: Int? {
        let values = devices.compactMap(\.batteryPercent)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    private let settingsStore: SettingsStore
    private let notificationService: NotificationService
    private let loginItemService: LoginItemService
    private let monitorService: BatteryMonitorService
    private var sleepWakeObserver: SleepWakeObserver?

    convenience init() {
        self.init(
            settingsStore: SettingsStore(),
            notificationService: NotificationService(),
            loginItemService: LoginItemService(),
            sharedBatteryStore: SharedBatteryStore(),
            reader: IORegistryBatteryReader()
        )
    }

    @MainActor
    init(
        settingsStore: SettingsStore,
        notificationService: NotificationService,
        loginItemService: LoginItemService,
        sharedBatteryStore: SharedBatteryStore,
        reader: any BatteryReader
    ) {
        self.settingsStore = settingsStore
        self.notificationService = notificationService
        self.loginItemService = loginItemService
        self.thresholdPercent = settingsStore.thresholdPercent
        self.notificationsEnabled = settingsStore.notificationsEnabled

        monitorService = BatteryMonitorService(
            reader: reader,
            settingsStore: settingsStore,
            notificationService: notificationService,
            sharedStore: sharedBatteryStore
        )

        if let cachedSnapshot = sharedBatteryStore.loadSnapshotEnvelope() {
            devices = cachedSnapshot.devices.sortedForDisplay
            lastSuccessfulRefreshAt = cachedSnapshot.generatedAt
            lastRefreshAt = cachedSnapshot.generatedAt
        }

        monitorService.onStateChange = { [weak self] state in
            self?.apply(state: state)
        }

        sleepWakeObserver = SleepWakeObserver { [weak self] in
            Task { await self?.refresh(reason: .wakeFromSleep) }
        }

        Task {
            await refreshNotificationAuthorization()
            refreshLoginItemStatus()
            monitorService.start()
        }
    }

    func refresh(reason: RefreshReason = .manual) async {
        await monitorService.refresh(reason: reason)
    }

    func refreshNotificationAuthorization() async {
        notificationAuthorizationStatus = await notificationService.authorizationStatus()
    }

    func requestNotificationPermission() async {
        do {
            _ = try await notificationService.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshNotificationAuthorization()
    }

    func openNotificationSettings() {
        notificationService.openNotificationSettings()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLoginItemStatus()
    }

    func refreshLoginItemStatus() {
        launchAtLoginEnabled = loginItemService.isEnabled
    }

    private func apply(state: MonitorState) {
        devices = state.devices.sortedForDisplay
        lastRefreshAt = state.lastRefreshAt
        lastSuccessfulRefreshAt = state.lastSuccessfulRefreshAt
        isRefreshing = state.isRefreshing
        errorMessage = state.errorMessage
        diagnosticsMessage = state.diagnosticsMessage
    }
}
