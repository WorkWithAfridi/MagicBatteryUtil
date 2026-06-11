//
//  AppConfiguration.swift
//  MagicBatteryUtil
//

import Foundation

enum AppConfiguration {
    static let appGroupID = "group.com.workwithafridi.MagicBatteryUtil"
    static let widgetKind = "MagicBatteryWidget"
    static let widgetSnapshotFilename = "latest-battery-snapshot.json"
    static let widgetExportFilename = "latest-widget-snapshot.json"
    static let widgetStaleInterval: TimeInterval = 30 * 60
    static let batteryPollingInterval: TimeInterval = 60
}
