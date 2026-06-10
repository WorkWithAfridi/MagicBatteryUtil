//
//  SleepWakeObserver.swift
//  MagicBatteryUtil
//

import AppKit
import Foundation

final class SleepWakeObserver {
    private var observer: NSObjectProtocol?

    init(onWake: @escaping @MainActor () -> Void) {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onWake()
            }
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
