//
//  LCDesignTokens.swift
//  LiveContainerSwiftUI
//
//  Centralized Design System tokens, button styles, and safe localization fallback (iOS 15+ safe).
//

import SwiftUI
import UIKit

// MARK: - Design Tokens

enum LCSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

enum LCRadius {
    static let badge: CGFloat = 8
    static let control: CGFloat = 10
    static let pill: CGFloat = 12
    static let card: CGFloat = 16
    static let sheet: CGFloat = 20

    /// Standard Apple iOS continuous icon squircle ratio.
    static func icon(for side: CGFloat) -> CGFloat {
        side * 0.2237
    }
}

enum LCHitTarget {
    /// Apple HIG minimum recommended touch target.
    static let minimum: CGFloat = 44
}

// MARK: - Safe Localization Helper

extension String {
    /// Looks up a localization key via `.loc`, returning `fallback` if the key is missing from Localizable.xcstrings.
    func loc(fallback: String) -> String {
        let resolved = self.loc
        return resolved == self ? fallback : resolved
    }
}

// MARK: - Button Styles

struct LCPrimaryButtonStyle: ButtonStyle {
    @ObservedObject private var theme = LCTheme.shared
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? LCSpacing.sm : LCSpacing.md)
            .padding(.vertical, compact ? 9 : 11)
            .frame(minHeight: compact ? 36 : LCHitTarget.minimum)
            .background(
                RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                    .fill(isEnabled ? theme.accent : Color(UIColor.tertiarySystemFill))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.6)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct LCSecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var theme = LCTheme.shared
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundColor(isEnabled ? .primary : .secondary)
            .padding(.horizontal, compact ? LCSpacing.sm : LCSpacing.md)
            .padding(.vertical, compact ? 9 : 11)
            .frame(minHeight: compact ? 36 : LCHitTarget.minimum)
            .background(
                RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1.0) : 0.5)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
