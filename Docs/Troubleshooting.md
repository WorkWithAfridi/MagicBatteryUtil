# MagicBatteryUtil Troubleshooting

## No devices appear

- Confirm the Magic device is paired to the Mac over Bluetooth.
- Wait up to one minute for the next automatic refresh cycle.
- Wake the Mac if it recently slept.
- Open the app and check the Support section in Settings for any diagnostics.

## Notifications are not working

- Open `Settings > Notifications` inside the app.
- Check whether authorization is `Denied` or `Not requested`.
- Use the in-app button to open macOS Notifications settings.

## Launch at Login does not stick

- Toggle it again from `Settings > Startup`.
- macOS may reject the change because of user restrictions or local system policy.
- If that happens, the app will show the latest status and any returned error.

## Battery value says Unknown

- Some devices expose identity information but not a battery percentage for a given read.
- The app handles that safely and will try again on the next automatic refresh.

## Data looks stale

- The app refreshes on launch, after wake, and every minute while running.
- If data remains stale, reconnect the device and confirm it still appears in macOS Bluetooth settings.
