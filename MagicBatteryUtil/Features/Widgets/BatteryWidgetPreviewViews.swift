//
//  BatteryWidgetPreviewViews.swift
//  MagicBatteryUtil
//

import SwiftUI

struct SmallBatteryWidgetPreview: View {
    let snapshot: BatterySnapshotEnvelope

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MagicBatteryUtil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if snapshot.isStale {
                    StatusPill(status: .stale)
                }
            }

            if let device = snapshot.lowestBatteryDevice {
                VStack(alignment: .leading, spacing: 8) {
                    Label(device.displayName, systemImage: device.kind.symbolName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(device.batteryLabel)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(device.displayStatus(threshold: snapshot.thresholdPercent, staleInterval: snapshot.staleInterval).color)
                    BatteryLevelBar(
                        percent: device.batteryPercent,
                        color: device.displayStatus(threshold: snapshot.thresholdPercent, staleInterval: snapshot.staleInterval).color
                    )
                }
            } else {
                Text("No device data")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
            Text(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel()
    }
}

struct MediumBatteryWidgetPreview: View {
    let snapshot: BatterySnapshotEnvelope

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accessory Status")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                if snapshot.isStale {
                    StatusPill(status: .stale)
                }
            }

            ForEach(snapshot.devices.prefix(3)) { device in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(device.displayName, systemImage: device.kind.symbolName)
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text(device.batteryLabel)
                            .foregroundStyle(device.displayStatus(threshold: snapshot.thresholdPercent, staleInterval: snapshot.staleInterval).color)
                    }
                    BatteryLevelBar(
                        percent: device.batteryPercent,
                        color: device.displayStatus(threshold: snapshot.thresholdPercent, staleInterval: snapshot.staleInterval).color
                    )
                }
            }

            Spacer()
            Text(snapshot.isStale ? "Cached data is older than 30 minutes" : "Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel()
    }
}

struct BatteryWidgetPreviewViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            SmallBatteryWidgetPreview(snapshot: .preview)
                .frame(width: 170, height: 170)

            MediumBatteryWidgetPreview(snapshot: .preview)
                .frame(width: 360, height: 170)
        }
        .padding()
        .background(AppTheme.pageGradient)
    }
}
