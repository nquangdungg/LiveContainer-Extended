//
//  LCDashboardHeaderView.swift
//  LiveContainerSwiftUI
//
//  LiveContainer Extended — Clean Native Dashboard Header (iOS 15+ safe)
//

import SwiftUI

struct LCDashboardHeaderView: View {
    @ObservedObject private var statusManager = LCDashboardStatusManager.shared
    @ObservedObject private var theme = LCTheme.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onRefreshAll: () -> Void
    var onOpenSideStore: () -> Void
    var onInstallIPA: () -> Void
    var onInstallURL: () -> Void
    var onOpenSettings: () -> Void

    /// When true, Refresh pill shows a spinner and is non-interactive.
    var isRefreshingApps: Bool = false

    private var canRefreshApps: Bool {
        statusManager.localDevVPN.isConnected && !isRefreshingApps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {
            // Status Row: Certificate & LocalDevVPN
            HStack(spacing: LCSpacing.sm) {
                statusCard(
                    title: "lc.dashboard.certificate".loc,
                    subtitle: statusManager.certificate.subtitle,
                    badge: statusManager.certificate.title,
                    color: statusManager.certificate.indicatorColor,
                    icon: "checkmark.shield.fill",
                    action: onOpenSettings
                )
                statusCard(
                    title: "lc.dashboard.vpn".loc,
                    subtitle: statusManager.localDevVPN.subtitle,
                    badge: statusManager.localDevVPN.isConnected
                        ? "lc.dashboard.vpnConnected".loc
                        : "lc.dashboard.vpnOff".loc,
                    color: statusManager.localDevVPN.indicatorColor,
                    icon: statusManager.localDevVPN.isConnected ? "network" : "network.slash",
                    action: {
                        if !statusManager.localDevVPN.isConnected {
                            statusManager.openLocalDevVPN()
                        } else {
                            statusManager.refresh()
                        }
                    }
                )
            }

            // Action Bar: Smart primary hierarchy
            // When VPN is connected -> Refresh Apps is primary; otherwise Install is primary
            HStack(spacing: LCSpacing.xs) {
                Menu {
                    Button(action: onInstallIPA) {
                        Label("lc.dashboard.installFromFiles".loc, systemImage: "doc.badge.plus")
                    }
                    Button(action: onInstallURL) {
                        Label("lc.dashboard.installFromURL".loc, systemImage: "link")
                    }
                } label: {
                    let installIsPrimary = !canRefreshApps && !isRefreshingApps
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.bold))
                        Text("lc.dashboard.install".loc)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: LCHitTarget.minimum)
                    .padding(.horizontal, LCSpacing.xs)
                    .foregroundColor(installIsPrimary ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                            .fill(installIsPrimary ? theme.accent : theme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                            .stroke(installIsPrimary ? Color.clear : theme.cardBorder, lineWidth: 1)
                    )
                }
                .accessibilityLabel("lc.dashboard.install".loc)

                actionPill(
                    title: isRefreshingApps
                        ? "lc.dashboard.refreshing".loc
                        : "lc.dashboard.refreshApps".loc,
                    icon: "arrow.triangle.2.circlepath",
                    filled: canRefreshApps || isRefreshingApps,
                    enabled: canRefreshApps,
                    isBusy: isRefreshingApps,
                    action: onRefreshAll
                )

                actionPill(
                    title: "lc.dashboard.sidestore".loc,
                    icon: "shippingbox.fill",
                    filled: false,
                    enabled: true,
                    action: onOpenSideStore
                )
            }
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.top, LCSpacing.xxs)
        .padding(.bottom, LCSpacing.xs)
        .onAppear { statusManager.refresh() }
    }

    private func statusCard(
        title: String,
        subtitle: String,
        badge: String,
        color: Color,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }

                Text(badge)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LCSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .lcCard(radius: LCRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func actionPill(
        title: String,
        icon: String,
        filled: Bool,
        enabled: Bool,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else { return }
            action()
        } label: {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(filled ? Color.white : theme.accent)
                } else {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                }
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: LCHitTarget.minimum)
            .padding(.horizontal, LCSpacing.xs)
            .foregroundColor(filled && (enabled || isBusy) ? Color.white : (enabled ? Color.primary : theme.secondaryText))
            .background(
                RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                    .fill(filled && (enabled || isBusy) ? theme.accent : theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                    .stroke(filled && (enabled || isBusy) ? Color.clear : theme.cardBorder, lineWidth: 1)
            )
            .opacity(enabled || isBusy ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityHint(filled ? "lc.dashboard.refreshAppsHint".loc : "")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: enabled)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isBusy)
    }
}
