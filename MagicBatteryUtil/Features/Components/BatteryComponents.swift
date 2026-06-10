//
//  BatteryComponents.swift
//  MagicBatteryUtil
//

import SwiftUI

struct StatusPill: View {
    let status: BatteryDisplayStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.14), in: Capsule())
            .foregroundStyle(status.color)
    }
}

struct BatteryLevelBar: View {
    let percent: Int?
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.black.opacity(0.06))

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.95), color.opacity(0.60)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
        .frame(height: 10)
    }

    private var progress: Double {
        let clamped = min(max(Double(percent ?? 0), 0), 100)
        return clamped / 100
    }
}

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}
