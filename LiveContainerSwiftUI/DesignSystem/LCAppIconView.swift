//
//  LCAppIconView.swift
//  LiveContainerSwiftUI
//
//  Single source of truth for rendering app icons with Apple continuous squircle,
//  dark mode icon support, monogram fallback, and hairline border.
//

import SwiftUI
import UIKit

struct LCAppIconView: View {
    let appInfo: LCAppInfo
    let displayName: String
    var size: CGFloat = 56
    var darkModeIcon: Bool = false
    var showBorder: Bool = true
    var isSigning: Bool = false

    @ObservedObject private var theme = LCTheme.shared

    private var cornerRadius: CGFloat {
        LCRadius.icon(for: size)
    }

    var body: some View {
        ZStack {
            if let img = appInfo.iconIsDarkIcon(darkModeIcon) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                theme.accent.opacity(0.16)
                    .overlay(
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: max(14, size * 0.42), weight: .bold, design: .rounded))
                            .foregroundColor(theme.accent)
                    )
            }

            if isSigning {
                Color.black.opacity(0.45)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .controlSize(size >= 52 ? .regular : .small)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(showBorder ? 0.08 : 0), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
