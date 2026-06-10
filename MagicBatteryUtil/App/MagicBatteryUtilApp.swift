//
//  MagicBatteryUtilApp.swift
//  MagicBatteryUtil
//
//  Created by Khondakar Afridi on 10/6/26.
//

import AppKit
import SwiftUI

final class MagicBatteryAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}

@main
struct MagicBatteryUtilApp: App {
    @NSApplicationDelegateAdaptor(MagicBatteryAppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("Magic Battery Monitor", id: "main") {
            DashboardView()
                .environmentObject(appModel)
                .frame(minWidth: 760, minHeight: 520)
                .preferredColorScheme(.dark)
        }

        MenuBarExtra("Magic Battery", systemImage: appModel.menuBarSymbolName) {
            MenuBarContentView()
                .environmentObject(appModel)
                .frame(width: 320)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(width: 460)
                .preferredColorScheme(.dark)
        }
    }
}
