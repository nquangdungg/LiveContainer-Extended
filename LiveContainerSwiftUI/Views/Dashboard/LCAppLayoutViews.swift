//
//  LCAppLayoutViews.swift
//  LiveContainerSwiftUI
//
//  Unified List / Grid / Compact / SpringBoard cells powered by DesignSystem
//  (LCAppIconView, LCAppCapabilityIcons, LCAppRowActions) — iOS 15+ safe.
//

import SwiftUI
import UIKit

// MARK: - Section Header

struct LCAppsSectionHeader: View {
    @ObservedObject private var theme = LCTheme.shared
    @EnvironmentObject private var sortManager: LCAppSortManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var appCount: Int
    var onManageCustomSort: () -> Void

    var body: some View {
        HStack(spacing: LCSpacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text("lc.dashboard.myApps".loc)
                    .font(.title3.bold())
                Text(appCount == 0
                    ? "lc.dashboard.noAppsYet".loc
                    : "lc.dashboard.appsInstalledCount %lld".localizeWithFormat(appCount))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer(minLength: 0)

            // Layout segmented control
            HStack(spacing: 2) {
                ForEach(LCAppLayoutMode.allCases) { mode in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            theme.appLayout = mode
                        }
                    } label: {
                        Image(systemName: mode.systemImage)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.appLayout == mode ? .white : theme.secondaryText)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(theme.appLayout == mode ? theme.accent : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.displayName)
                    .accessibilityAddTraits(theme.appLayout == mode ? .isSelected : [])
                }
            }
            .padding(3)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LCRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.control, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )

            // Sort menu
            Menu {
                Picker("lc.common.sortBy".loc(fallback: "Sort by"), selection: $sortManager.appSortType) {
                    ForEach(AppSortType.allCases, id: \.self) { sortType in
                        Label(sortType.displayName, systemImage: sortType.systemImage)
                            .tag(sortType)
                    }
                }
                if sortManager.appSortType == .custom {
                    Divider()
                    Button(action: onManageCustomSort) {
                        Label("lc.appList.manageCustomOrder".loc(fallback: "Manage custom order"), systemImage: "slider.horizontal.3")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: LCRadius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: LCRadius.control, style: .continuous)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("lc.common.sort".loc(fallback: "Sort"))
            .onChange(of: sortManager.appSortType) { newValue in
                if newValue == .custom {
                    onManageCustomSort()
                }
            }
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.top, LCSpacing.xs)
        .padding(.bottom, LCSpacing.xxs)
    }
}

// MARK: - Empty / Search No-Results State

struct LCAppsEmptyState: View {
    var isSearching: Bool = false
    var searchQuery: String = ""
    var onClearSearch: (() -> Void)? = nil
    var onImport: () -> Void
    var onInstallURL: () -> Void
    var onOpenSideStore: () -> Void

    var body: some View {
        if isSearching {
            LCEmptyStateView(
                systemImage: "magnifyingglass",
                title: "lc.search.noResultsTitle".loc(fallback: "No Matching Apps"),
                message: "lc.search.noResultsSubtitle %@".localizeWithFormat(searchQuery)
            ) {
                if let onClearSearch {
                    Button(action: onClearSearch) {
                        Label("lc.search.clear".loc(fallback: "Clear Search"), systemImage: "xmark.circle")
                    }
                    .buttonStyle(LCSecondaryButtonStyle(compact: true))
                }
            }
        } else {
            LCEmptyStateView(
                systemImage: "square.stack.3d.up.slash",
                title: "lc.dashboard.emptyTitle".loc,
                message: "lc.dashboard.emptySubtitle".loc
            ) {
                HStack(spacing: LCSpacing.sm) {
                    Menu {
                        Button(action: onImport) {
                            Label("lc.dashboard.installFromFiles".loc, systemImage: "doc.badge.plus")
                        }
                        Button(action: onInstallURL) {
                            Label("lc.dashboard.installFromURL".loc, systemImage: "link")
                        }
                    } label: {
                        Label("lc.dashboard.installApp".loc, systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, LCSpacing.md)
                            .frame(minHeight: LCHitTarget.minimum)
                            .background(
                                RoundedRectangle(cornerRadius: LCRadius.pill, style: .continuous)
                                    .fill(LCTheme.shared.accent)
                            )
                    }

                    Button(action: onOpenSideStore) {
                        Label("lc.dashboard.sidestore".loc, systemImage: "shippingbox")
                    }
                    .buttonStyle(LCSecondaryButtonStyle())
                }
            }
        }
    }
}

// MARK: - Grid Cell

struct LCAppGridCell: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    let actions: LCAppRowActionCallbacks

    var body: some View {
        Button(action: { actions.onRun(nil) }) {
            VStack(spacing: LCSpacing.xs) {
                ZStack(alignment: .topTrailing) {
                    LCAppIconView(
                        appInfo: appModel.appInfo,
                        displayName: appModel.displayName,
                        size: 56,
                        darkModeIcon: darkModeIcon,
                        isSigning: appModel.isSigningInProgress
                    )
                    .frame(maxWidth: .infinity)

                    Button(action: actions.onOpenSettings) {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("lc.tabView.settings".loc)
                }

                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Text(appModel.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        LCAppCapabilityIcons(appModel: appModel)
                    }

                    Text(appModel.uiSelectedContainer?.name ?? appModel.bundleIdentifier)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(LCSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 132)
            .lcCard(radius: LCRadius.card)
            .opacity(appModel.isAppRunning ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
        .lcAppRowActions(appModel: appModel, callbacks: actions)
    }
}

// MARK: - Compact Row

struct LCAppCompactRow: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    let actions: LCAppRowActionCallbacks

    var body: some View {
        HStack(spacing: LCSpacing.sm) {
            Button(action: { actions.onRun(nil) }) {
                HStack(spacing: LCSpacing.sm) {
                    LCAppIconView(
                        appInfo: appModel.appInfo,
                        displayName: appModel.displayName,
                        size: 40,
                        darkModeIcon: darkModeIcon,
                        isSigning: appModel.isSigningInProgress
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(appModel.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            LCAppCapabilityIcons(appModel: appModel)
                        }

                        Text("\(appModel.version) · \(appModel.uiSelectedContainer?.name ?? "lc.appBanner.noDataFolder".loc)")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Explicit Settings button (never use chevron for launch rows)
            Button(action: actions.onOpenSettings) {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundColor(theme.secondaryText)
                    .frame(width: LCHitTarget.minimum, height: LCHitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("lc.tabView.settings".loc)
        }
        .padding(.leading, LCSpacing.sm)
        .padding(.trailing, LCSpacing.xxs)
        .padding(.vertical, 6)
        .lcCard(radius: LCRadius.pill)
        .opacity(appModel.isAppRunning ? 0.65 : 1.0)
        .lcAppRowActions(appModel: appModel, callbacks: actions)
    }
}

// MARK: - SpringBoard-style Icon Cell (Inline Grid Mode)

struct LCSpringBoardAppCell: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    let actions: LCAppRowActionCallbacks
    @State private var pressed = false

    var body: some View {
        VStack(spacing: 6) {
            LCAppIconView(
                appInfo: appModel.appInfo,
                displayName: appModel.displayName,
                size: 60,
                darkModeIcon: darkModeIcon,
                isSigning: appModel.isSigningInProgress
            )
            .scaleEffect(!reduceMotion && pressed ? 0.92 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: pressed)

            Text(appModel.displayName)
                .font(.caption2.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 74)
        }
        .frame(width: 78)
        .contentShape(Rectangle())
        .onTapGesture {
            if reduceMotion {
                actions.onRun(nil)
            } else {
                pressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    pressed = false
                    actions.onRun(nil)
                }
            }
        }
        .lcAppRowActions(appModel: appModel, callbacks: actions)
    }
}
