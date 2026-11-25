//
//  LCStatusComponents.swift
//  LiveContainerSwiftUI
//
//  Reusable status badges, capability strips, install progress banner, toast banner,
//  and empty/search states (iOS 15+ safe).
//

import SwiftUI
import UIKit

// MARK: - Status Badge

struct LCStatusBadge: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.bold())
                .lineLimit(1)
        }
        .foregroundColor(filled ? .white : tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? tint : tint.opacity(0.14))
        )
    }
}

// MARK: - App Capability Badges Strip

struct LCAppCapabilityIcons: View {
    @ObservedObject var appModel: LCAppModel

    var body: some View {
        HStack(spacing: 4) {
            if appModel.uiIsShared {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .accessibilityLabel("Shared")
            }
            if appModel.uiIsJITNeeded && !appModel.uiIs32bit {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                    .accessibilityLabel("JIT")
            }
            if appModel.uiIs32bit {
                Text("32")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .accessibilityLabel("32-bit")
            }
            if appModel.uiIsLocked && !appModel.uiIsHidden {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .accessibilityLabel("Locked")
            }
        }
    }
}

// MARK: - Inline Feedback Toast Banner

struct LCToastBanner: View {
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = LCTheme.shared.success

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundColor(tint)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - Install Stage & Progress Banner

enum LCInstallStage: Equatable {
    case idle
    case extracting
    case signing
    case finalizing
    case completed

    var localizedTitle: String {
        switch self {
        case .idle:
            return ""
        case .extracting:
            return "lc.install.stage.extracting".loc(fallback: "Extracting IPA…")
        case .signing:
            return "lc.install.stage.signing".loc(fallback: "Signing app…")
        case .finalizing:
            return "lc.install.stage.finalizing".loc(fallback: "Finalizing installation…")
        case .completed:
            return "lc.install.stage.completed".loc(fallback: "Installation complete")
        }
    }
}

struct LCInstallProgressBanner: View {
    @ObservedObject private var theme = LCTheme.shared
    let progress: Float
    let stage: LCInstallStage

    private var clampedProgress: Double {
        Double(max(0, min(1, progress)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.xs) {
            HStack(spacing: LCSpacing.xs) {
                if stage == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.success)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.accent)
                }
                Text(stage.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if progress > 0 && stage != .completed {
                    Text("\(Int(clampedProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            if progress > 0 {
                ProgressView(value: clampedProgress, total: 1.0)
                    .tint(stage == .completed ? theme.success : theme.accent)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(theme.accent)
            }
        }
        .padding(14)
        .lcCard(radius: LCRadius.card)
    }
}

// MARK: - Reusable Empty / Search No-Results State

struct LCEmptyStateView<Actions: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    init(
        systemImage: String,
        title: String,
        message: String,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: LCSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .light))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LCSpacing.md)

            actions()
                .padding(.top, LCSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, LCSpacing.md)
    }
}

extension LCEmptyStateView where Actions == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.init(systemImage: systemImage, title: title, message: message) {
            EmptyView()
        }
    }
}
