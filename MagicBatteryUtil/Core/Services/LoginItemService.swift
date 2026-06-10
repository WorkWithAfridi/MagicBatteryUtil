//
//  LoginItemService.swift
//  MagicBatteryUtil
//

import Foundation
import ServiceManagement

final class LoginItemService {
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw NSError(
                domain: "MagicBatteryUtil.LoginItemService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Launch at login requires macOS 13 or newer."]
            )
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
