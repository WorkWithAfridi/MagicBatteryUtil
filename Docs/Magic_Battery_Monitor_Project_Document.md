# Magic Battery Monitor

**Project Specification, Architecture, and Development Checklist**

_Target platform: macOS | Primary stack: Swift, SwiftUI, WidgetKit, ServiceManagement, UserNotifications, IOKit/IORegistry_

# 1. Executive Summary

Magic Battery Monitor is a lightweight native macOS utility that monitors the battery percentage of Apple Magic Keyboard, Magic Mouse, and optionally Magic Trackpad. It provides a live in-app dashboard, a menu bar presence, local low-battery notifications, launch-at-login control from inside the app, and desktop widgets that display current accessory battery state.

The recommended architecture is a SwiftUI menu bar plus regular app-window utility. Battery information should be read from IORegistry/HID device properties rather than from CoreBluetooth as the primary data path. Monitoring should use low-frequency polling with immediate refresh on launch, wake, and a one-minute interval. WidgetKit should display cached state from an App Group store, while the main app remains responsible for actual monitoring and notifications.

# 2. Product Goals and Non-Goals

| Goals | Non-Goals / Constraints |
| --- | --- |
| Show live battery percentage inside the app for Magic Keyboard, Magic Mouse, and optionally Magic Trackpad. | Do not claim true battery health such as cycle count or capacity degradation; Apple accessories usually expose battery percentage, not health metrics. |
| Notify when a device drops below a configurable threshold, default 30%. | Do not send repeated notifications on every poll. |
| Start automatically when macOS starts, controlled from the app settings screen. | Avoid legacy login-item APIs unless supporting pre-macOS 13 explicitly. |
| Provide desktop widgets with meaningful battery status, last seen time, and low-battery indicators. | Widgets should not be the monitoring engine because WidgetKit timelines are system-scheduled, not live. |
| Remain extremely lightweight, reliable, and native. | Avoid Electron, background daemons, networking, databases, or high-frequency Bluetooth scans. |

# 3. Functional Requirements

| ID | Feature | Requirement |
| --- | --- | --- |
| FR-001 | Live app dashboard | User can open the app and see current battery levels for all detected supported devices. |
| FR-002 | Menu bar status | User can access key device levels and actions from the macOS menu bar. |
| FR-003 | Low-battery notifications | User receives a local notification when a device drops below the configured threshold, default 30%. |
| FR-004 | Launch at login toggle | User can enable or disable auto-start directly from the app. |
| FR-005 | Device observation | App monitors device battery while running and refreshes after launch, wake, and periodic polling. |
| FR-006 | Desktop widgets | User can place widgets on desktop/Notification Center showing battery percentage, status, and last updated time. |
| FR-007 | Settings persistence | Threshold, launch-at-login preference, notification suppression state, and widget shared state persist across launches. |
| FR-008 | Disconnected handling | App shows devices as disconnected/stale instead of incorrectly showing old values as current. |

# 4. Non-Functional Requirements

- [x] Idle CPU usage should be effectively zero between polling cycles.

- [x] No network access is required.

- [x] No user account, cloud service, analytics, or telemetry is required for MVP.

- [x] Battery polling interval should default to 1 minute and be configurable only if needed.

- [x] App should not require administrator privileges.

- [x] App should gracefully handle missing permissions, missing devices, stale cached values, and sleeping/waking.

- [x] Storage should use UserDefaults/App Group JSON only; no database is needed.

- [ ] The app should run well on Apple Silicon and Intel Macs supported by the chosen deployment target.

# 5. Recommended Architecture

Use a single native macOS app target plus a WidgetKit extension. The main app owns monitoring, notifications, launch-at-login state, and live UI. The widget extension reads the latest published snapshot from an App Group store.

```
MagicBatteryMonitor.app
├── App target
│   ├── SwiftUI App entry point
│   ├── MainWindow / DashboardView
│   ├── MenuBarExtra
│   ├── BatteryMonitorService
│   ├── BatteryReader
│   │   ├── IORegistryBatteryReader
│   │   └── MockBatteryReader for tests/previews
│   ├── NotificationService
│   ├── LoginItemService
│   ├── SleepWakeObserver
│   ├── SharedBatteryStore
│   └── SettingsStore
└── MagicBatteryWidgetExtension
    ├── SmallBatteryWidget
    ├── MediumBatteryWidget
    └── BatteryWidgetTimelineProvider
```

# 6. Data Flow

```
Launch app / wake from sleep / timer tick
        ↓
BatteryMonitorService.refresh()
        ↓
IORegistryBatteryReader reads supported HID battery values
        ↓
Normalize into DeviceBatterySnapshot models
        ↓
Update live SwiftUI state + save to App Group shared store
        ↓
Evaluate threshold crossing rules
        ↓
Send local notification if needed
        ↓
WidgetCenter.reloadAllTimelines() so widgets pick up the newest snapshot
```

# 7. Technical Approach by Capability

## 7.1 Live app dashboard

The main app should include a normal SwiftUI WindowGroup so the user can open the app and see a live dashboard. The dashboard subscribes to an ObservableObject or @Observable view model that BatteryMonitorService updates after each refresh. Use a manual Refresh button for immediate reads.

```swift
@main
struct MagicBatteryMonitorApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appModel)
        }

        MenuBarExtra("Magic Battery", systemImage: "battery.75") {
            MenuBarContentView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }
}
```

## 7.2 Battery reading

The primary reader should query IORegistry for Apple HID event services and parse battery percentage fields. Start with a Process wrapper around /usr/sbin/ioreg for fast delivery; later replace it with direct IOKit calls if App Store sandboxing or performance requires it.

```bash
/usr/sbin/ioreg -r -l -c AppleDeviceManagementHIDEventService
```

Expected properties can include Product and BatteryPercent. The parser should match Product names containing Magic Keyboard, Magic Mouse, or Magic Trackpad and normalize them into app-level device models.

```swift
struct DeviceBatterySnapshot: Codable, Identifiable, Equatable {
    var id: String              // stable device identity if available, otherwise normalized product name
    var productName: String
    var kind: DeviceKind        // keyboard, mouse, trackpad, unknown
    var batteryPercent: Int?
    var connectionState: ConnectionState
    var lastSeenAt: Date
    var source: BatteryDataSource
}
```

## 7.3 Monitoring strategy

Use low-frequency polling. Recommended behavior: refresh immediately on app launch, every 1 minute, and after wake from sleep.

```swift
final class BatteryMonitorService {
    private var timer: Timer?

    func start() {
        refresh(reason: .appLaunch)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh(reason: .scheduledPoll)
        }
    }
}
```

## 7.4 Notifications

Use local notifications for low-battery alerts. Request authorization during onboarding or from Settings. Notify on threshold crossing, not on every poll. Maintain per-device suppression state so a user is not spammed.

```
if previousPercent >= threshold && currentPercent < threshold {
    notificationService.sendLowBatteryNotification(for: device)
}

// Reset suppression only after the device rises back above the threshold
// or after a long cooldown if you choose to support reminders.
```

## 7.5 Launch at login

Use ServiceManagement SMAppService on macOS 13 and later. The Settings screen should expose a Launch at Login toggle. The toggle calls register() or unregister(), then reads the service status back to show whether macOS accepted the change.

```swift
import ServiceManagement

final class LoginItemService {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

## 7.6 Widgets

Use a WidgetKit extension for desktop/Notification Center widgets. The widget must not perform Bluetooth or IORegistry monitoring itself. It should read the latest snapshot from the App Group shared store and render that cached state. The app should call WidgetCenter.shared.reloadAllTimelines() after saving a new snapshot.

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.example.MagicBatteryMonitor")
sharedDefaults?.set(encodedSnapshot, forKey: "latestBatterySnapshot")
WidgetCenter.shared.reloadAllTimelines()
```

# 8. UI Specification

## 8.1 App dashboard

- [x] Device cards for Keyboard, Mouse, and Trackpad.

- [x] Large battery percentage and graphical battery indicator.

- [x] Status labels: Good, Low, Critical, Disconnected, Stale.

- [x] Last checked timestamp.

- [ ] Manual Refresh button.

- [x] Open Settings button.

- [x] Notification permission warning if permission is not granted.

- [x] Empty state explaining that no supported Magic devices are currently detected.

## 8.2 Settings screen

- [x] Launch at Login toggle backed by SMAppService.

- [x] Low battery threshold selector, default 30%.

- [x] Enable/disable notifications toggle.

- [x] Request Notification Permission button if needed.

- [x] Polling interval display, default 1 minute; keep advanced interval control hidden unless needed.

- [x] Include supported devices list and troubleshooting link/instructions.

## 8.3 Menu bar view

- [x] Compact list of current device percentages.

- [x] Low-battery highlighting for devices below threshold.

- [ ] Refresh Now action.

- [x] Open Magic Battery Monitor action.

- [x] Settings action.

- [x] Quit action.

## 8.4 Widget designs

- [ ] Small widget: lowest battery device plus status.

- [ ] Medium widget: all detected devices with percentages and status labels.

- [ ] Large widget, optional: all devices plus trend/last seen details.

- [ ] Show stale data warning if last update is older than a configured freshness window, for example 30 minutes.

- [ ] Use App Group cached snapshot; do not perform live monitoring in widget extension.

# 9. State, Persistence, and Notification Rules

Store user settings in standard UserDefaults. Store widget-visible snapshots in App Group UserDefaults or a small App Group JSON file. Keep the shared data model small and Codable.

```swift
struct BatterySnapshotEnvelope: Codable {
    var generatedAt: Date
    var devices: [DeviceBatterySnapshot]
    var thresholdPercent: Int
}

struct NotificationMemory: Codable {
    var deviceID: String
    var lastNotifiedAt: Date?
    var wasBelowThreshold: Bool
}
```

Notification rule: send a notification only when a detected device transitions from above-or-equal threshold to below threshold. Reset the below-threshold suppression when the device rises back to threshold or above.

# 10. Permissions, Privacy, and Distribution

- [x] Notification permission is required for low-battery alerts.

- [x] No Bluetooth permission should be requested for the IORegistry-first implementation.

- [x] No location, contacts, files, microphone, camera, network, or analytics permission is required.

- [x] The app should not require admin privileges.

- [ ] For direct distribution, sign and notarize the app.

- [ ] For Mac App Store distribution, test the sandboxed IORegistry path early; shelling out to ioreg may need reconsideration or replacement with direct IOKit.

# 11. Edge Cases and Reliability Plan

| Edge Case | Expected Behavior |
| --- | --- |
| Device temporarily disconnected | Show Disconnected after the device is absent from the latest scan; keep last seen timestamp visible. |
| Old cached widget data | Widget shows Stale if generatedAt exceeds freshness window. |
| Notification permission denied | Dashboard and settings show a warning and a button to open System Settings. |
| Launch-at-login denied or restricted | Show actual SMAppService status instead of only the desired setting. |
| BatteryPercent missing | Show Unknown for that device and log a debug-only parser event. |
| Multiple keyboards/mice | Support multiple devices if stable identifiers are available; otherwise group by product name carefully. |
| Sleep/wake | Refresh after wake; avoid relying on timers firing during sleep. |
| IORegistry output format changes | Keep parser unit tests with sample fixtures and fail gracefully. |

# 12. Development Plan and Milestones

## Phase 0 - Technical spike

- [ ] Confirm IORegistry command returns Product and BatteryPercent for your devices.

- [x] Save sample outputs as parser test fixtures.

- [ ] Confirm notifications and SMAppService work in a minimal macOS app.

## Phase 1 - Core monitor MVP

- [x] Create SwiftUI macOS project.

- [x] Implement BatteryReader protocol and IORegistryBatteryReader.

- [ ] Implement parser and unit tests.

- [x] Implement BatteryMonitorService with launch/manual/timer refresh.

- [x] Implement dashboard cards showing live battery values.

## Phase 2 - Notifications and settings

- [x] Request notification permission.

- [x] Implement threshold crossing logic.

- [x] Implement Launch at Login toggle with SMAppService.

- [x] Persist settings and notification memory.

- [x] Add error and permission UI states.

## Phase 3 - Menu bar app polish

- [x] Add MenuBarExtra using .window style.

- [x] Add compact live menu bar content.

- [x] Add Refresh/Open/Settings/Quit actions.

- [x] Tune app activation behavior.

## Phase 4 - WidgetKit extension

- [ ] Enable App Group capability on app and widget.

- [x] Publish latest snapshot to shared storage.

- [x] Create small and medium widgets.

- [x] Reload timelines after snapshot updates.

- [x] Add stale-data handling.

## Phase 5 - Reliability, signing, release

- [x] Handle sleep/wake refresh.

- [ ] Add parser fixture tests and notification rule tests.

- [ ] Profile CPU/memory.

- [ ] Sign and notarize direct distribution build.

- [x] Create release notes and troubleshooting docs.

# 13. Thorough Development Checklist

## Project setup

- [x] Create macOS SwiftUI app target in Xcode.

- [x] Set deployment target. Recommended: macOS 13+ for SMAppService and modern SwiftUI menu bar APIs.

- [x] Create WidgetKit extension target.

- [ ] Create App Group identifier and enable it for both app and widget targets.

- [x] Add entitlements only as required; keep the app sandbox/privacy footprint minimal.

- [x] Create shared Swift package or shared source folder for Codable models used by app and widget.

## Battery reader

- [x] Define BatteryReading protocol.

- [x] Implement IORegistryBatteryReader using Process to call /usr/sbin/ioreg for MVP.

- [x] Parse Product, BatteryPercent, and available identity fields.

- [x] Normalize product names into DeviceKind.

- [x] Handle missing BatteryPercent without crashing.

- [ ] Add parser tests using saved ioreg sample output.

- [x] Add mock reader for SwiftUI previews and unit tests.

- [ ] Consider direct IOKit implementation after MVP if needed.

## Monitoring service

- [x] Refresh on app launch.

- [x] Refresh when dashboard appears.

- [x] Refresh on manual button press.

- [x] Schedule 10-minute polling timer.

- [x] Observe wake-from-sleep and refresh after wake.

- [x] Prevent concurrent refresh calls.

- [x] Debounce widget timeline reloads if refreshes happen close together.

- [x] Mark data stale if last successful read is too old.

## Live app UI

- [x] Build dashboard cards for Keyboard, Mouse, Trackpad, and unknown supported devices.

- [x] Show percentage, status, last seen, and connection state.

- [x] Add manual Refresh button and loading indicator.

- [x] Add empty state for no devices detected.

- [x] Add notification permission warning state.

- [x] Add Settings entry point.

- [x] Ensure app can be opened from Dock/Finder and from menu bar.

## Settings

- [x] Implement threshold setting with default 30%.

- [x] Validate threshold range, e.g. 5-80%.

- [x] Implement Launch at Login toggle with SMAppService.

- [x] Read back actual login item status after register/unregister.

- [x] Implement notification enable/disable preference.

- [x] Implement Request Notification Permission action.

- [x] Add troubleshooting text for devices not appearing.

## Notifications

- [x] Request authorization through UNUserNotificationCenter.

- [x] Create low-battery notification content with device name and percent.

- [x] Trigger only on above-threshold to below-threshold transition.

- [x] Persist per-device notification memory.

- [x] Reset memory when device recovers above threshold.

- [ ] Add optional reminder cooldown if desired, default off for MVP.

- [ ] Write tests for threshold crossing behavior.

## Menu bar

- [x] Add MenuBarExtra scene.

- [x] Use .window style if you want richer SwiftUI content instead of a basic menu.

- [x] Display compact battery rows.

- [x] Add Refresh Now action.

- [x] Add Open App action.

- [x] Add Settings action.

- [x] Add Quit action.

- [x] Ensure menu bar content updates when monitor state changes.

## 13.1 Implementation notes

- [x] Core macOS app MVP is now implemented in the main app target.
- [x] WidgetKit extension target is now part of the project.
- [ ] Automated tests are still outstanding and should be added before release.

## Widgets

- [x] Create small widget layout.

- [x] Create medium widget layout.

- [x] Read shared snapshot from App Group store.

- [x] Show stale warning when snapshot age exceeds freshness window.

- [x] Support no-data state.

- [x] Call WidgetCenter.shared.reloadAllTimelines() after saving new snapshot.

- [ ] Test widgets on desktop and Notification Center.

- [ ] Verify macOS widget font sizing and layout.

## Quality and release

- [ ] Run app for a full day and confirm no notification spam.

- [ ] Confirm CPU remains near zero while idle.

- [ ] Confirm memory usage is stable over long runtime.

- [ ] Confirm behavior across sleep/wake cycles.

- [ ] Confirm app restarts automatically at login when enabled.

- [ ] Confirm disabling launch at login works.

- [ ] Confirm widgets recover after reboot once the app publishes a new snapshot.

- [ ] Sign and notarize the app for direct distribution.

- [ ] Prepare README with installation, permissions, and troubleshooting.

# 14. Suggested Source Structure

```
MagicBatteryMonitor/
├── App/
│   ├── MagicBatteryMonitorApp.swift
│   ├── AppModel.swift
│   └── AppCommands.swift
├── Features/
│   ├── Dashboard/
│   ├── Settings/
│   ├── MenuBar/
│   └── Onboarding/
├── Services/
│   ├── BatteryMonitorService.swift
│   ├── IORegistryBatteryReader.swift
│   ├── NotificationService.swift
│   ├── LoginItemService.swift
│   ├── SleepWakeObserver.swift
│   └── SharedBatteryStore.swift
├── Shared/
│   ├── DeviceBatterySnapshot.swift
│   ├── DeviceKind.swift
│   ├── BatterySnapshotEnvelope.swift
│   └── Constants.swift
├── WidgetExtension/
│   ├── MagicBatteryWidget.swift
│   ├── BatteryWidgetEntry.swift
│   └── BatteryWidgetViews.swift
└── Tests/
    ├── IORegistryParserTests.swift
    ├── NotificationRuleTests.swift
    └── SharedStoreTests.swift
```

# 15. MVP Acceptance Criteria

- [ ] Opening the app shows live battery percentage for connected Magic Keyboard and Magic Mouse.

- [ ] Clicking Refresh updates values without restarting the app.

- [ ] When battery percentage drops below the configured threshold, a local notification appears once per threshold crossing.

- [ ] Launch at Login can be enabled and disabled from inside Settings.

- [ ] The app launches automatically after login when enabled.

- [ ] Menu bar view shows current battery percentages and has Refresh/Open/Settings/Quit actions.

- [ ] Desktop widget shows the latest saved battery state and last updated time.

- [ ] Widget displays stale/no-data states correctly.

- [ ] The app uses negligible CPU while idle and does not require network or admin privileges.

- [ ] No repeated low-battery spam occurs during long-running tests.

# 16. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| IORegistry schema differences | Collect samples from multiple macOS versions and write parser fixture tests. |
| App Store sandbox restrictions | Decide early whether distribution is direct/notarized or Mac App Store. Test sandboxed builds early. |
| Widget update timing | Treat widgets as cached glanceable UI; do not promise second-by-second live values. |
| Notification fatigue | Notify only on threshold crossing and persist suppression state. |
| Bluetooth/CoreBluetooth complexity | Avoid CoreBluetooth for MVP; use system-exposed HID battery data. |

# 17. Technical References

- Apple Developer Documentation: SMAppService - register and control LoginItems, LaunchAgents, and LaunchDaemons on macOS 13 and later. https://developer.apple.com/documentation/servicemanagement/smappservice

- Apple Developer Documentation: MenuBarExtra - SwiftUI menu bar utility entry point. https://developer.apple.com/documentation/SwiftUI/MenuBarExtra

- Apple Developer Documentation: WidgetKit - build glanceable widgets outside the app. https://developer.apple.com/documentation/widgetkit

- Apple Developer Documentation: Creating a Widget Extension. https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension

- Apple Developer Documentation: UserNotifications - local notifications. https://developer.apple.com/documentation/usernotifications

- Apple Developer Documentation: Scheduling a notification locally from your app. https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app
