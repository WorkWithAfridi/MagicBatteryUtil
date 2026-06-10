//
//  AppTheme.swift
//  MagicBatteryUtil
//

import SwiftUI

enum AppTheme {
    static let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.06, blue: 0.09),
            Color(red: 0.07, green: 0.10, blue: 0.16),
            Color(red: 0.10, green: 0.08, blue: 0.14)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.12, blue: 0.20),
            Color(red: 0.08, green: 0.30, blue: 0.28),
            Color(red: 0.72, green: 0.34, blue: 0.13)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelFill = Color.white.opacity(0.08)
    static let panelStroke = Color.white.opacity(0.10)
    static let shadowColor = Color.black.opacity(0.32)
    static let good = Color(red: 0.34, green: 0.86, blue: 0.53)
    static let low = Color(red: 0.97, green: 0.67, blue: 0.27)
    static let critical = Color(red: 1.00, green: 0.39, blue: 0.38)
    static let neutral = Color(red: 0.67, green: 0.73, blue: 0.80)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let tertiaryText = Color.white.opacity(0.54)
}

struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowColor, radius: 18, y: 10)
    }
}

extension View {
    func glassPanel() -> some View {
        modifier(GlassPanelModifier())
    }
}
