//
//  LCDashboardHeaderView.swift
//  LiveContainerSwiftUI
//
//  LiveContainer Extended — Hero dashboard
//

import SwiftUI

struct LCDashboardHeaderView: View {
    @ObservedObject private var statusManager = LCDashboardStatusManager.shared
    @ObservedObject private var theme = LCTheme.shared
    
    var onRefreshAll: () -> Void
    var onOpenSideStore: () -> Void
    var onInstallIPA: () -> Void
    var onInstallURL: () -> Void
    var onOpenSettings: () -> Void
    
    /// When true, primary Refresh pill shows a spinner and is non-interactive.
    var isRefreshingApps: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text("LiveContainer")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("lc.dashboard.badgeExtended".loc)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.14))
                        .clipShape(Capsule())
                    Text("lc.dashboard.badgeFork".loc)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accentOpposite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accentOpposite.opacity(0.14))
                        .clipShape(Capsule())
                    Spacer(minLength: 0)
                    // Status-only refresh (certificate / VPN) — distinct from apps Refresh pill
                    Button {
                        statusManager.refresh()
                    } label: {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 34, height: 34)
                            .background(theme.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("lc.dashboard.refreshStatus".loc)
                    .accessibilityHint("lc.dashboard.refreshStatusHint".loc)
                }
            }
            
            // Status
            HStack(spacing: 12) {
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
                        }
                    }
                )
            }
            
            // Actions: Refresh Apps · SideStore · Install (menu)
            // Rule: Refresh Apps requires VPN connected
            HStack(spacing: 10) {
                actionPill(
                    title: isRefreshingApps
                        ? "lc.dashboard.refreshing".loc
                        : "lc.dashboard.refreshApps".loc,
                    icon: "arrow.triangle.2.circlepath",
                    filled: true,
                    enabled: statusManager.localDevVPN.isConnected && !isRefreshingApps,
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
                
                Menu {
                    Button {
                        onInstallIPA()
                    } label: {
                        Label("lc.dashboard.installFromFiles".loc, systemImage: "doc.badge.plus")
                    }
                    Button {
                        onInstallURL()
                    } label: {
                        Label("lc.dashboard.installFromURL".loc, systemImage: "link")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("lc.dashboard.install".loc)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(Color.primary)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .onAppear { statusManager.refresh() }
    }
    
    private func statusCard(title: String, subtitle: String, badge: String, color: Color, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                Text(badge)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .lcCard(radius: 16)
        }
        .buttonStyle(.plain)
    }
    
    private func actionPill(title: String, icon: String, filled: Bool, enabled: Bool, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
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
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(filled && (enabled || isBusy) ? Color.white : (enabled ? Color.primary : theme.secondaryText))
            .background(filled && (enabled || isBusy) ? theme.accent : theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(filled && (enabled || isBusy) ? Color.clear : theme.cardBorder, lineWidth: 1)
            )
            .opacity(enabled || isBusy ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityHint(filled ? "lc.dashboard.refreshAppsHint".loc : "")
        .animation(.easeInOut(duration: 0.2), value: enabled)
        .animation(.easeInOut(duration: 0.2), value: isBusy)
        .animation(.easeInOut(duration: 0.2), value: theme.accentPreset)
    }
}
