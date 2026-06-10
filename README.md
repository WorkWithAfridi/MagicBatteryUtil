# MagicBatteryUtil

MagicBatteryUtil is a native macOS SwiftUI utility that monitors battery levels for Apple Magic accessories.

## Features

- Live dashboard for connected Magic devices
- Menu bar access to current battery levels
- Low-battery notifications
- Launch at login support
- Cached battery snapshots for future widget integration

## Folder Structure

```text
MagicBatteryUtil/
├── App/
├── Core/
│   ├── Models/
│   ├── Services/
│   └── Storage/
├── Features/
│   ├── Dashboard/
│   ├── MenuBar/
│   └── Settings/
└── Assets.xcassets/
Docs/
└── Magic_Battery_Monitor_Project_Document.md
```

## Development

- Platform: macOS 13+
- Project: `MagicBatteryUtil.xcodeproj`
- Build without signing:

```bash
xcodebuild -scheme MagicBatteryUtil -project MagicBatteryUtil.xcodeproj CODE_SIGNING_ALLOWED=NO build
```

## Notes

- The main app target is implemented.
- Widget extension and automated tests are still pending.
- The detailed product plan lives in [Docs/Magic_Battery_Monitor_Project_Document.md](Docs/Magic_Battery_Monitor_Project_Document.md).
- Troubleshooting guidance lives in [Docs/Troubleshooting.md](Docs/Troubleshooting.md).
- A draft release note outline lives in [Docs/Release_Notes_Draft.md](Docs/Release_Notes_Draft.md).
