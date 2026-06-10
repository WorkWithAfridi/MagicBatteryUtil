//
//  MagicBatteryWidget.swift
//  MagicBatteryWidgetExtension
//

import SwiftUI
import WidgetKit

private enum WidgetDataConfiguration {
    static let appGroupID = "group.com.workwithafridi.MagicBatteryUtil"
    static let latestSnapshotKey = "shared.latestSnapshot"
    static let staleInterval: TimeInterval = 30 * 60
}

private enum WidgetDeviceKind: String, Codable {
    case keyboard
    case mouse
    case trackpad
    case unknown

    var symbolName: String {
        switch self {
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "computermouse"
        case .trackpad:
            return "rectangle.and.hand.point.up.left"
        case .unknown:
            return "battery.100"
        }
    }
}

private enum WidgetConnectionState: String, Codable {
    case connected
    case disconnected
}

private struct WidgetDeviceSnapshot: Codable, Identifiable {
    var id: String
    var productName: String
    var kind: WidgetDeviceKind
    var batteryPercent: Int?
    var connectionState: WidgetConnectionState
    var lastSeenAt: Date

    var displayName: String {
        productName.isEmpty ? "Magic Accessory" : productName
    }

    var batteryLabel: String {
        guard let batteryPercent else { return "Unknown" }
        return "\(batteryPercent)%"
    }

    func status(threshold: Int, now: Date = Date()) -> WidgetStatus {
        if now.timeIntervalSince(lastSeenAt) > WidgetDataConfiguration.staleInterval {
            return .stale
        }
        if connectionState == .disconnected {
            return .disconnected
        }
        guard let batteryPercent else {
            return .unknown
        }
        if batteryPercent < min(10, threshold) {
            return .critical
        }
        if batteryPercent < threshold {
            return .low
        }
        return .good
    }
}

private struct WidgetSnapshotEnvelope: Codable {
    var generatedAt: Date
    var devices: [WidgetDeviceSnapshot]
    var thresholdPercent: Int

    var lowestBatteryDevice: WidgetDeviceSnapshot? {
        devices
            .filter { $0.connectionState == .connected }
            .sorted { ($0.batteryPercent ?? 101) < ($1.batteryPercent ?? 101) }
            .first
    }
}

private enum WidgetStatus {
    case good
    case low
    case critical
    case disconnected
    case stale
    case unknown

    var title: String {
        switch self {
        case .good:
            return "Good"
        case .low:
            return "Low"
        case .critical:
            return "Critical"
        case .disconnected:
            return "Disconnected"
        case .stale:
            return "Stale"
        case .unknown:
            return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .good:
            return Color(red: 0.34, green: 0.86, blue: 0.53)
        case .low:
            return Color(red: 0.97, green: 0.67, blue: 0.27)
        case .critical:
            return Color(red: 1.00, green: 0.39, blue: 0.38)
        case .disconnected, .stale, .unknown:
            return Color.white.opacity(0.7)
        }
    }
}

private struct BatteryWidgetEntry: TimelineEntry {
    let date: Date
    let envelope: WidgetSnapshotEnvelope?
    let message: String?
}

private struct BatteryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryWidgetEntry {
        BatteryWidgetEntry(date: Date(), envelope: sampleEnvelope, message: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry() -> BatteryWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetDataConfiguration.appGroupID)
        let decoder = JSONDecoder()

        guard let data = defaults?.data(forKey: WidgetDataConfiguration.latestSnapshotKey),
              let envelope = try? decoder.decode(WidgetSnapshotEnvelope.self, from: data) else {
            return BatteryWidgetEntry(
                date: Date(),
                envelope: nil,
                message: "Open MagicBatteryUtil to generate the first shared snapshot."
            )
        }

        let isStale = Date().timeIntervalSince(envelope.generatedAt) > WidgetDataConfiguration.staleInterval
        return BatteryWidgetEntry(
            date: Date(),
            envelope: envelope,
            message: isStale ? "Data is older than 30 minutes." : nil
        )
    }

    private var sampleEnvelope: WidgetSnapshotEnvelope {
        WidgetSnapshotEnvelope(
            generatedAt: Date(),
            devices: [
                WidgetDeviceSnapshot(
                    id: "sample-keyboard",
                    productName: "Magic Keyboard",
                    kind: .keyboard,
                    batteryPercent: 76,
                    connectionState: .connected,
                    lastSeenAt: Date()
                ),
                WidgetDeviceSnapshot(
                    id: "sample-mouse",
                    productName: "Magic Mouse",
                    kind: .mouse,
                    batteryPercent: 28,
                    connectionState: .connected,
                    lastSeenAt: Date()
                )
            ],
            thresholdPercent: 30
        )
    }
}

struct MagicBatteryWidget: Widget {
    let kind = "MagicBatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryWidgetProvider()) { entry in
            BatteryWidgetEntryView(entry: entry)
                .widgetContainerBackground()
        }
        .configurationDisplayName("Magic Battery")
        .description("Shows the latest cached battery status for your Magic accessories.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct BatteryWidgetEntryView: View {
    let entry: BatteryWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let device = entry.envelope?.lowestBatteryDevice {
                VStack(alignment: .leading, spacing: 8) {
                    Label(device.displayName, systemImage: device.kind.symbolName)
                        .font(.headline)
                        .lineLimit(2)
                    Text(device.batteryLabel)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(device.status(threshold: entry.envelope?.thresholdPercent ?? 30).color)
                    widgetBar(percent: device.batteryPercent, color: device.status(threshold: entry.envelope?.thresholdPercent ?? 30).color)
                }
            } else {
                Text(entry.message ?? "No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            footer
        }
        .padding(16)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ForEach(entry.envelope?.devices.prefix(3) ?? []) { device in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(device.displayName, systemImage: device.kind.symbolName)
                            .lineLimit(1)
                        Spacer()
                        Text(device.batteryLabel)
                            .foregroundStyle(device.status(threshold: entry.envelope?.thresholdPercent ?? 30).color)
                    }
                    widgetBar(percent: device.batteryPercent, color: device.status(threshold: entry.envelope?.thresholdPercent ?? 30).color)
                }
            }

            if let message = entry.message {
                Spacer()
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Spacer()
                footer
            }
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            Text("Magic Battery")
                .font(.caption.weight(.semibold))
            Spacer()
            if let envelope = entry.envelope,
               Date().timeIntervalSince(envelope.generatedAt) > WidgetDataConfiguration.staleInterval {
                statusPill(title: "Stale")
            }
        }
    }

    private var footer: some View {
        Text(entry.envelope?.generatedAt.formatted(date: .omitted, time: .shortened) ?? "No snapshot")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func statusPill(title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func widgetBar(percent: Int?, color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.white.opacity(0.10))

                RoundedRectangle(cornerRadius: 999)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * max(0, min(CGFloat(Double(percent ?? 0) / 100), 1)))
            }
        }
        .frame(height: 8)
    }
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            background(Color.black.opacity(0.18))
        }
    }
}
