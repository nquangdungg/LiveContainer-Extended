//
//  LCAppLayoutViews.swift
//  LiveContainerSwiftUI
//
//  List / Grid / Compact + section chrome — feature parity with banner actions
//

import SwiftUI

// MARK: - Section header

struct LCAppsSectionHeader: View {
    @ObservedObject private var theme = LCTheme.shared
    @EnvironmentObject private var sortManager: LCAppSortManager
    var appCount: Int
    var onManageCustomSort: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("lc.dashboard.myApps".loc)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(appCount == 0
                    ? "lc.dashboard.noAppsYet".loc
                    : "lc.dashboard.appsInstalledCount %lld".localizeWithFormat(appCount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
            
            // Layout segmented control
            HStack(spacing: 0) {
                ForEach(LCAppLayoutMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            theme.appLayout = mode
                        }
                    } label: {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.appLayout == mode ? Color.white : theme.secondaryText)
                            .frame(width: 34, height: 28)
                            .background(theme.appLayout == mode ? theme.accent : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.rawValue)
                }
            }
            .padding(3)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            
            // Sort menu (parity with original toolbar)
            Menu {
                Picker("Sort by", selection: $sortManager.appSortType) {
                    ForEach(AppSortType.allCases, id: \.self) { sortType in
                        Label(sortType.displayName, systemImage: sortType.systemImage)
                            .tag(sortType)
                    }
                }
                if sortManager.appSortType == .custom {
                    Divider()
                    Button {
                        onManageCustomSort()
                    } label: {
                        Label("Manage custom order", systemImage: "slider.horizontal.3")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
            }
            .onChange(of: sortManager.appSortType) { newValue in
                if newValue == .custom {
                    onManageCustomSort()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Empty state

struct LCAppsEmptyState: View {
    @ObservedObject private var theme = LCTheme.shared
    var onImport: () -> Void
    var onInstallURL: () -> Void
    var onOpenSideStore: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.secondaryText)
            Text("lc.dashboard.emptyTitle".loc)
                .font(.system(size: 17, weight: .semibold))
            Text("lc.dashboard.emptySubtitle".loc)
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 10) {
                Menu {
                    Button(action: onImport) {
                        Label("lc.dashboard.installFromFiles".loc, systemImage: "doc.badge.plus")
                    }
                    Button(action: onInstallURL) {
                        Label("lc.dashboard.installFromURL".loc, systemImage: "link")
                    }
                } label: {
                    Label("lc.dashboard.installApp".loc, systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button(action: onOpenSideStore) {
                    Label("lc.dashboard.sidestore".loc, systemImage: "shippingbox")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .lcCard(radius: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Shared context menu actions

struct LCAppContextActions: ViewModifier {
    @ObservedObject var appModel: LCAppModel
    var onOpenSettings: () -> Void
    var onRemove: () -> Void
    var onToggleHidden: () -> Void
    
    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                Task {
                    do { try await appModel.runApp() } catch { }
                }
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            Button {
                Task {
                    do { try await appModel.runApp(multitask: true) } catch { }
                }
            } label: {
                Label("Run in Multitask", systemImage: "rectangle.on.rectangle")
            }
            Divider()
            Button(action: onOpenSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
                Task { await appModel.toggleHidden() }
                onToggleHidden()
            } label: {
                Label(appModel.appInfo.isHidden ? "Unhide" : "Hide", systemImage: "eye.slash")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

extension View {
    func lcAppContextMenu(
        appModel: LCAppModel,
        onOpenSettings: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onToggleHidden: @escaping () -> Void = {}
    ) -> some View {
        modifier(LCAppContextActions(
            appModel: appModel,
            onOpenSettings: onOpenSettings,
            onRemove: onRemove,
            onToggleHidden: onToggleHidden
        ))
    }
}

// MARK: - Grid cell

struct LCAppGridCell: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    var onLaunch: () -> Void
    var onOpenSettings: () -> Void
    var onRemove: () -> Void
    
    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 10) {
                iconView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(appModel.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(appModel.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128)
            .lcCard(radius: 16)
        }
        .buttonStyle(.plain)
        .lcAppContextMenu(appModel: appModel, onOpenSettings: onOpenSettings, onRemove: onRemove)
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let img = appModel.appInfo.iconIsDarkIcon(darkModeIcon) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.accent.opacity(0.2))
                .overlay(
                    Text(String(appModel.displayName.prefix(1)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.accent)
                )
        }
    }
}

// MARK: - Compact row

struct LCAppCompactRow: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    var onLaunch: () -> Void
    var onOpenSettings: () -> Void
    var onRemove: () -> Void
    
    var body: some View {
        Button(action: onLaunch) {
            HStack(spacing: 12) {
                Group {
                    if let img = appModel.appInfo.iconIsDarkIcon(darkModeIcon) {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        theme.accent.opacity(0.25)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appModel.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(appModel.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .lcCard(radius: 12)
        }
        .buttonStyle(.plain)
        .lcAppContextMenu(appModel: appModel, onOpenSettings: onOpenSettings, onRemove: onRemove)
    }
}


// MARK: - SpringBoard-style icon cell (tap to launch, long-press menu)

struct LCSpringBoardAppCell: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    var onLaunch: () -> Void
    var onOpenSettings: () -> Void
    var onRemove: () -> Void
    @State private var pressed = false
    
    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let img = appModel.appInfo.iconIsDarkIcon(darkModeIcon) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent.opacity(0.2))
                        .overlay(
                            Text(String(appModel.displayName.prefix(1)))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(theme.accent)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(pressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: pressed)
            
            Text(appModel.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .frame(width: 76)
        .contentShape(Rectangle())
        .onTapGesture {
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                pressed = false
                onLaunch()
            }
        }
        .lcAppContextMenu(appModel: appModel, onOpenSettings: onOpenSettings, onRemove: onRemove)
    }
}
