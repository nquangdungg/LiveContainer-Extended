//
//  LCSpringBoardShellView.swift
//  LiveContainerSwiftUI — Remade SpringBoard Home Shell
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum SBMetrics {
    static let columns = 4
    static let hPadding: CGFloat = 22
    static let vIconSpacing: CGFloat = 16
    static let labelHeight: CGFloat = 28
    static let dockInset: CGFloat = 16
    static let dockInnerH: CGFloat = 14
    static func cornerRadius(for side: CGFloat) -> CGFloat { side * 0.2237 }
    
    static func iconSide(containerWidth: CGFloat) -> CGFloat {
        let usable = containerWidth - hPadding * 2
        let raw = floor((usable - CGFloat(columns - 1) * 12) / CGFloat(columns))
        return min(62, max(48, raw))
    }
}

enum LCWallpaperStyle: String, CaseIterable, Identifiable {
    case cosmicAurora = "Cosmic Aurora"
    case midnightBlue = "Midnight Mesh"
    case sunsetGlow = "Sunset Radiance"
    case obsidian = "Obsidian Dark"
    
    var id: String { rawValue }
}

struct LCSpringBoardShellView: View {
    @EnvironmentObject var sharedModel: SharedModel
    @ObservedObject private var theme = LCTheme.shared
    @ObservedObject private var layout = LCSpringBoardLayoutStore.shared
    @ObservedObject private var statusManager = LCDashboardStatusManager.shared
    
    @State private var pageIndex: Int = 1
    @State private var editing = false
    @State private var searching = false
    @State private var showSwitcher = false
    @State private var showSettings = false
    @State private var openFolderId: UUID?
    @State private var choosingIPA = false
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var installBusy = false
    @State private var launchingId: String?
    
    @AppStorage("LCSpringBoardWallpaper", store: LCUtils.appGroupUserDefault)
    private var wallpaperStyle: LCWallpaperStyle = .cosmicAurora
    
    private func key(for app: LCAppModel) -> String {
        let rel = app.appInfo.relativeBundlePath ?? ""
        let bid = app.bundleIdentifier ?? ""
        return rel.isEmpty ? bid : rel
    }
    
    private var appsByKey: [String: LCAppModel] {
        var map: [String: LCAppModel] = [:]
        for app in sharedModel.apps {
            let k = key(for: app)
            if !k.isEmpty { map[k] = app }
            let bid = app.bundleIdentifier ?? ""
            if !bid.isEmpty { map[bid] = app }
        }
        return map
    }
    
    private var sideStoreAvailable: Bool {
        FileManager.default.fileExists(
            atPath: Bundle.main.bundleURL.appendingPathComponent("Frameworks/SideStoreApp.framework").path
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            let safe = geo.safeAreaInsets
            let width = geo.size.width
            let height = geo.size.height
            let iconSide = SBMetrics.iconSide(containerWidth: width)
            
            ZStack {
                wallpaperView
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Chrome Bar
                    topBar
                        .padding(.top, max(0, safe.top > 0 ? safe.top * 0.4 : 12))
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                    
                    // Main Paged Content
                    TabView(selection: $pageIndex) {
                        todayWidgetsPage(width: width)
                            .tag(0)
                        
                        ForEach(Array(layout.pages.indices), id: \.self) { idx in
                            iconGridPage(layout.pages[idx], pageIdx: idx, iconSide: iconSide, width: width)
                                .tag(idx + 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: editing ? .never : .always))
                    .frame(maxHeight: .infinity)
                    
                    // Floating Bottom Dock
                    dockBar(iconSide: iconSide)
                        .padding(.horizontal, SBMetrics.dockInset)
                        .padding(.bottom, max(safe.bottom, 10))
                }
                
                // Spotlight Search Overlay
                if searching {
                    LCSpringBoardSearchView(
                        apps: sharedModel.apps,
                        folders: layout.folders,
                        onLaunch: { launch($0) },
                        onOpenFolder: { openFolderId = $0; searching = false },
                        onDismiss: { withAnimation(.spring(response: 0.3)) { searching = false } }
                    )
                    .zIndex(20)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                // App Switcher Multitasking Overlay
                if showSwitcher {
                    LCSpringBoardSwitcherView(
                        apps: sharedModel.apps,
                        onSelect: { app in
                            withAnimation { showSwitcher = false }
                            launch(app)
                        },
                        onDismiss: { withAnimation(.spring(response: 0.3)) { showSwitcher = false } }
                    )
                    .zIndex(25)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Folder Expanded Overlay
                if let fid = openFolderId, let folder = layout.folder(for: fid) {
                    LCSpringBoardFolderOverlay(
                        folder: folder,
                        appsByKey: appsByKey,
                        iconSide: iconSide,
                        jiggling: editing,
                        onLaunch: { launch($0) },
                        onClose: { withAnimation(.spring(response: 0.3)) { openFolderId = nil } }
                    )
                    .zIndex(30)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
                
                // Installation busy progress
                if installBusy {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Installing IPA…")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .zIndex(40)
                }
            }
            .frame(width: width, height: height)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            seedLayoutIfNeeded()
            layout.reconcile(with: sharedModel.apps)
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                LCSettingsView().environmentObject(sharedModel)
            }
        }
        .betterFileImporter(isPresented: $choosingIPA, types: [.ipa, .tipa], multiple: false, callback: { urls in
            Task { await installIPA(urls[0]) }
        }, onDismiss: { choosingIPA = false })
        .alert("Error", isPresented: $errorShow) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorInfo) }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    guard !searching && !showSwitcher else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        editing = true
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { val in
                    if !editing && val.startLocation.y < 160 && val.translation.height > 60 {
                        withAnimation(.spring(response: 0.3)) { searching = true }
                    } else if !editing && val.translation.height < -80 {
                        withAnimation(.spring(response: 0.3)) { showSwitcher = true }
                    }
                }
        )
    }
    
    // MARK: - Dynamic Wallpapers
    
    @ViewBuilder
    private var wallpaperView: some View {
        switch wallpaperStyle {
        case .cosmicAurora:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.22),
                        Color(red: 0.12, green: 0.18, blue: 0.38),
                        Color(red: 0.03, green: 0.05, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.cyan.opacity(0.18))
                    .frame(width: 340, height: 340)
                    .blur(radius: 65)
                    .offset(x: -100, y: -180)
                Circle()
                    .fill(Color.purple.opacity(0.22))
                    .frame(width: 320, height: 320)
                    .blur(radius: 65)
                    .offset(x: 120, y: 160)
            }
        case .midnightBlue:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.06, blue: 0.12),
                        Color(red: 0.08, green: 0.12, blue: 0.24),
                        Color(red: 0.02, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 0, y: -60)
            }
        case .sunsetGlow:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.07, blue: 0.18),
                        Color(red: 0.28, green: 0.12, blue: 0.18),
                        Color(red: 0.08, green: 0.03, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.orange.opacity(0.20))
                    .frame(width: 320, height: 320)
                    .blur(radius: 65)
                    .offset(x: -80, y: -140)
                Circle()
                    .fill(Color.pink.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 100, y: 140)
            }
        case .obsidian:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.04, green: 0.04, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Top Chrome Bar
    
    private var topBar: some View {
        HStack {
            if editing {
                Button {
                    choosingIPA = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Install")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                
                Spacer()
                
                Text("Edit Home")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) { editing = false }
                    layout.save()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            } else {
                // Live status capsule
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusManager.localDevVPN.isConnected ? theme.success : theme.secondaryText)
                        .frame(width: 8, height: 8)
                    Text("LiveContainer")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { searching = true }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) { showSwitcher = true }
                    } label: {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Today Widgets Page (Page 0)
    
    private func todayWidgetsPage(width: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Widgets")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
                
                // Certificate Widget Card
                widgetCard(
                    title: "Certificate",
                    subtitle: statusManager.certificate.subtitle,
                    badge: statusManager.certificate.title,
                    icon: "checkmark.shield.fill",
                    color: statusManager.certificate.indicatorColor
                ) {
                    showSettings = true
                }
                
                // VPN Status Widget Card
                widgetCard(
                    title: "LocalDev VPN",
                    subtitle: statusManager.localDevVPN.subtitle,
                    badge: statusManager.localDevVPN.isConnected ? "Connected" : "Disconnected",
                    icon: statusManager.localDevVPN.isConnected ? "network" : "network.slash",
                    color: statusManager.localDevVPN.indicatorColor
                ) {
                    if !statusManager.localDevVPN.isConnected {
                        statusManager.openLocalDevVPN()
                    }
                }
                
                // Quick Apps Count Widget
                widgetCard(
                    title: "Container Apps",
                    subtitle: "\(sharedModel.apps.count) guest applications installed",
                    badge: "\(sharedModel.apps.count) Apps",
                    icon: "square.grid.2x2.fill",
                    color: theme.accent
                ) {
                    pageIndex = 1
                }
                
                // Wallpaper Picker Widget
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wallpaper Style")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 8) {
                        ForEach(LCWallpaperStyle.allCases) { wp in
                            Button {
                                withAnimation { wallpaperStyle = wp }
                            } label: {
                                Text(wp.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(wallpaperStyle == wp ? Color.white : Color.white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(wallpaperStyle == wp ? theme.accent : Color.white.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, SBMetrics.hPadding)
            .padding(.bottom, 20)
            .frame(maxWidth: width, alignment: .leading)
        }
    }
    
    private func widgetCard(
        title: String,
        subtitle: String,
        badge: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.15), in: Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.15), in: Capsule())
                    }
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Icon Grid Page
    
    private func iconGridPage(_ keys: [String], pageIdx: Int, iconSide: CGFloat, width: CGFloat) -> some View {
        let spacing = max(10, (width - SBMetrics.hPadding * 2 - iconSide * CGFloat(SBMetrics.columns)) / CGFloat(SBMetrics.columns - 1))
        let columns = Array(repeating: GridItem(.fixed(iconSide), spacing: spacing), count: SBMetrics.columns)
        
        return ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: SBMetrics.vIconSpacing) {
                ForEach(Array(keys.enumerated()), id: \.element) { index, k in
                    if let app = appsByKey[k] {
                        appIconCell(app: app, key: k, index: index, pageIdx: pageIdx, iconSide: iconSide)
                    }
                }
                
                ForEach(Array(layout.folders.enumerated()), id: \.element.id) { index, folder in
                    folderCell(folder, index: keys.count + index, iconSide: iconSide)
                }
            }
            .padding(.horizontal, SBMetrics.hPadding)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .frame(maxWidth: width)
        }
    }
    
    private func appIconCell(app: LCAppModel, key: String, index: Int, pageIdx: Int, iconSide: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LCSpringBoardPhysicsIcon(
                app: app,
                index: index + pageIdx * 10,
                iconSide: iconSide,
                jiggling: editing,
                isLaunching: launchingId == key
            ) {
                guard !editing else { return }
                launch(app)
            }
            .contextMenu {
                if !editing {
                    Button { launch(app) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    Button {
                        layout.folders.append(LCSpringBoardFolder(name: "Folder", appBundleIds: [key]))
                        layout.pages = layout.pages.map { $0.filter { $0 != key } }
                        layout.dock.removeAll { $0 == key }
                        layout.save()
                    } label: { Label("New Folder with App", systemImage: "folder.badge.plus") }
                }
            }
            
            if editing {
                Button {
                    layout.pages = layout.pages.map { $0.filter { $0 != key } }
                    layout.dock.removeAll { $0 == key }
                    layout.save()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .font(.system(size: 20))
                        .offset(x: -6, y: -6)
                }
            }
        }
        .frame(width: iconSide, alignment: .top)
    }
    
    // MARK: - 3x3 Authentic Mini Grid Folder Cell
    
    private func folderCell(_ folder: LCSpringBoardFolder, index: Int, iconSide: CGFloat) -> some View {
        let radius = SBMetrics.cornerRadius(for: iconSide)
        let miniSide = (iconSide - 16) / 3.0
        
        return VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: iconSide, height: iconSide)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                
                // 3x3 Mini Grid Preview
                let previewKeys = Array(folder.appBundleIds.prefix(9))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(miniSide), spacing: 3), count: 3), spacing: 3) {
                    ForEach(previewKeys, id: \.self) { k in
                        if let app = appsByKey[k], let img = app.appInfo.iconIsDarkIcon(false) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: miniSide, height: miniSide)
                                .clipShape(RoundedRectangle(cornerRadius: miniSide * 0.22, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: miniSide * 0.22, style: .continuous)
                                .fill(theme.accent.opacity(0.4))
                                .frame(width: miniSide, height: miniSide)
                        }
                    }
                }
                .frame(width: iconSide - 12, height: iconSide - 12)
            }
            .rotationEffect(.degrees(editing ? (index % 2 == 0 ? 2.2 : -2.2) : 0))
            .animation(
                editing ? .easeInOut(duration: 0.13).repeatForever(autoreverses: true) : .default,
                value: editing
            )
            
            Text(folder.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: iconSide + 8, height: SBMetrics.labelHeight, alignment: .top)
        }
        .frame(width: iconSide)
        .onTapGesture {
            if !editing {
                withAnimation(.spring(response: 0.3)) {
                    openFolderId = folder.id
                }
            }
        }
    }
    
    // MARK: - Dock Bar
    
    private func dockBar(iconSide: CGFloat) -> some View {
        HStack(spacing: 16) {
            if sideStoreAvailable {
                sideStoreDockIcon(iconSide: iconSide)
            }
            
            ForEach(Array(layout.dock.enumerated()), id: \.element) { index, k in
                if let app = appsByKey[k] {
                    appIconCell(app: app, key: k, index: index, pageIdx: 99, iconSide: iconSide)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, SBMetrics.dockInnerH)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        )
    }
    
    private func sideStoreDockIcon(iconSide: CGFloat) -> some View {
        let radius = SBMetrics.cornerRadius(for: iconSide)
        return VStack(spacing: 5) {
            Group {
                if let img = BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(false) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.blue.opacity(0.35))
                        .overlay(Image(systemName: "arrow.down.app.fill").foregroundStyle(.white))
                }
            }
            .frame(width: iconSide, height: iconSide)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            
            Text("SideStore")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: iconSide + 8, height: SBMetrics.labelHeight, alignment: .top)
        }
        .frame(width: iconSide)
        .onTapGesture {
            guard !editing else { return }
            LCUtils.openSideStore(delegate: nil)
        }
    }
    
    private func seedLayoutIfNeeded() {
        if layout.dock.isEmpty && (layout.pages.isEmpty || (layout.pages.count == 1 && layout.pages[0].isEmpty)) {
            let keys = sharedModel.apps.map { key(for: $0) }.filter { !$0.isEmpty }
            layout.dock = Array(keys.prefix(4))
            let dockSet = Set(layout.dock)
            layout.pages = [keys.filter { !dockSet.contains($0) }]
            layout.save()
        }
    }
    
    private func launch(_ app: LCAppModel) {
        let k = key(for: app)
        launchingId = k
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            do {
                try await app.runApp()
            } catch {
                errorInfo = "\(error)"
                errorShow = true
            }
            launchingId = nil
        }
    }
    
    private func installIPA(_ url: URL) async {
        installBusy = true
        defer { installBusy = false }
        NotificationCenter.default.post(
            name: NSNotification.InstallAppNotification,
            object: ["url": url]
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - SpringBoard Physics Icon with Phase-Offset Wobble

struct LCSpringBoardPhysicsIcon: View {
    @ObservedObject var app: LCAppModel
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    @ObservedObject private var theme = LCTheme.shared
    
    var index: Int
    var iconSide: CGFloat = 60
    var jiggling: Bool
    var isLaunching: Bool
    var onLaunch: () -> Void
    
    private var radius: CGFloat { SBMetrics.cornerRadius(for: iconSide) }
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.accent.opacity(0.2))
                
                if let img = app.appInfo.iconIsDarkIcon(darkModeIcon) {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: iconSide * 1.04, height: iconSide * 1.04)
                        .frame(width: iconSide, height: iconSide)
                        .clipped()
                } else {
                    Text(String(app.displayName.prefix(1)))
                        .font(.system(size: iconSide * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: iconSide, height: iconSide)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .scaleEffect(isLaunching ? 1.08 : 1.0)
            // Phase-offset organic jiggle
            .rotationEffect(.degrees(jiggling ? (index % 2 == 0 ? 2.3 : -2.3) : 0))
            .animation(
                jiggling
                    ? .easeInOut(duration: 0.12 + Double(index % 3) * 0.02).repeatForever(autoreverses: true)
                    : .spring(response: 0.3, dampingFraction: 0.7),
                value: jiggling || isLaunching
            )
            
            Text(app.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSide + 8, height: SBMetrics.labelHeight, alignment: .top)
        }
        .frame(width: iconSide)
        .contentShape(Rectangle())
        .onTapGesture(perform: onLaunch)
    }
}

// MARK: - Search View

struct LCSpringBoardSearchView: View {
    let apps: [LCAppModel]
    let folders: [LCSpringBoardFolder]
    var onLaunch: (LCAppModel) -> Void
    var onOpenFolder: (UUID) -> Void
    var onDismiss: () -> Void
    @State private var query = ""
    
    private var filtered: [LCAppModel] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return apps }
        return apps.filter {
            $0.displayName.lowercased().contains(q) || ($0.bundleIdentifier ?? "").lowercased().contains(q)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Apps & Folders", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                    Button("Cancel", action: onDismiss)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 56)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(filtered, id: \.self) { app in
                            Button {
                                onLaunch(app)
                                onDismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    if let img = app.appInfo.iconIsDarkIcon(false) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.displayName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text(app.bundleIdentifier ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - App Switcher Multitasking Card Deck

struct LCSpringBoardSwitcherView: View {
    let apps: [LCAppModel]
    var onSelect: (LCAppModel) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onDismiss)
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)
                
                HStack {
                    Text("App Switcher")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Close", action: onDismiss)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(apps, id: \.self) { app in
                            Button {
                                onSelect(app)
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 170, height: 280)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                        
                                        VStack(spacing: 14) {
                                            if let img = app.appInfo.iconIsDarkIcon(false) {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 64, height: 64)
                                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                                            }
                                            Text(app.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, 10)
                                        }
                                    }
                                    
                                    Text(app.displayName)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.96))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

// MARK: - Folder Expanded Overlay

struct LCSpringBoardFolderOverlay: View {
    let folder: LCSpringBoardFolder
    let appsByKey: [String: LCAppModel]
    var iconSide: CGFloat = 60
    var jiggling: Bool
    var onLaunch: (LCAppModel) -> Void
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onClose)
            
            VStack(spacing: 18) {
                Text(folder.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: iconSide), spacing: 20)], spacing: 20) {
                    ForEach(Array(folder.appBundleIds.enumerated()), id: \.element) { index, key in
                        if let app = appsByKey[key] {
                            LCSpringBoardPhysicsIcon(
                                app: app,
                                index: index,
                                iconSide: iconSide,
                                jiggling: jiggling,
                                isLaunching: false
                            ) {
                                onLaunch(app)
                                onClose()
                            }
                        }
                    }
                }
                .padding(16)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(28)
        }
    }
}
