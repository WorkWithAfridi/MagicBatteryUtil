//
//  MagicBatteryUtilApp.swift
//  MagicBatteryUtil
//
//  Created by Khondakar Afridi on 10/6/26.
//

import SwiftUI

@main
struct MagicBatteryUtilApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("Magic Battery Monitor", id: "main") {
            DashboardView()
                .environmentObject(appModel)
                .frame(minWidth: 760, minHeight: 520)
        }

        MenuBarExtra("Magic Battery", systemImage: appModel.menuBarSymbolName) {
            MenuBarContentView()
                .environmentObject(appModel)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(width: 460)
        }
    }
}
