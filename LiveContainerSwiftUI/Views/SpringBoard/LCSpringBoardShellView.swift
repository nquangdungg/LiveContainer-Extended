//
//  LCSpringBoardShellView.swift
//  LiveContainerSwiftUI — SpringBoard home shell (layout inspired by VibeContainers metrics)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum SBMetrics {
    static let columns = 4
    static let hPadding: CGFloat = 20
    static let vIconSpacing: CGFloat = 14
    static let labelHeight: CGFloat = 28
    static let dockInset: CGFloat = 12
    static let dockInnerH: CGFloat = 14
    /// iOS home icon corner radius ≈ 22.37% of side
    static func cornerRadius(for side: CGFloat) -> CGFloat { side * 0.2237 }
    
    /// Fit 4 columns into available width. Cap at 60pt (iPhone standard).
    static func iconSide(containerWidth: CGFloat) -> CGFloat {
        let usable = containerWidth - hPadding * 2
        let raw = floor((usable - CGFloat(columns - 1) * 8) / CGFloat(columns))
        return min(60, max(48, raw))
    }
}

struct LCSpringBoardShellView: View {
    @EnvironmentObject var sharedModel: SharedModel
    @ObservedObject private var theme = LCTheme.shared
    @ObservedObject private var layout = LCSpringBoardLayoutStore.shared
    
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
            let dockHeight = iconSide + SBMetrics.labelHeight + SBMetrics.dockInnerH * 2
            let topChrome: CGFloat = editing ? 44 : 8
            
            ZStack {
                wallpaper.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar(iconSide: iconSide)
                        .padding(.top, max(0, safe.top > 0 ? 0 : 8))
                        .frame(height: topChrome)
                        .padding(.horizontal, 16)
                    
                    TabView(selection: $pageIndex) {
                        todayPage(width: width)
                            .tag(0)
                        ForEach(Array(layout.pages.indices), id: \.self) { idx in
                            iconPage(layout.pages[idx], iconSide: iconSide, width: width)
                                .tag(idx + 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: editing ? .never : .always))
                    .frame(maxHeight: .infinity)
                    
                    dockBar(iconSide: iconSide)
                        .padding(.horizontal, SBMetrics.dockInset)
                        .padding(.bottom, max(safe.bottom, 8))
                }
                
                if searching {
                    LCSpringBoardSearchView(
                        apps: sharedModel.apps,
                        folders: layout.folders,
                        onLaunch: { launch($0) },
                        onOpenFolder: { openFolderId = $0; searching = false },
                        onDismiss: { searching = false }
                    )
                    .zIndex(20)
                }
                
                if showSwitcher {
                    LCSpringBoardSwitcherView(
                        apps: sharedModel.apps,
                        onSelect: { showSwitcher = false; launch($0) },
                        onDismiss: { showSwitcher = false }
                    )
                    .zIndex(15)
                }
                
                if let fid = openFolderId, let folder = layout.folder(for: fid) {
                    LCSpringBoardFolderOverlay(
                        folder: folder,
                        appsByKey: appsByKey,
                        iconSide: iconSide,
                        jiggling: editing,
                        onLaunch: { launch($0) },
                        onClose: { openFolderId = nil }
                    )
                    .zIndex(12)
                }
                
                if installBusy {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Installing…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .zIndex(30)
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
            LongPressGesture(minimumDuration: 0.55)
                .onEnded { _ in
                    guard !searching else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { editing = true }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if !editing && value.startLocation.y < 140 && value.translation.height > 70 {
                        withAnimation { searching = true }
                    } else if !editing && value.translation.height < -90 {
                        withAnimation { showSwitcher = true }
                    }
                }
        )
    }
    
    // MARK: Top bar — no clock in SpringBoard mode
    
    private func topBar(iconSide: CGFloat) -> some View {
        HStack {
            if editing {
                Button {
                    choosingIPA = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.22)))
                }
                Spacer()
                Button {
                    withAnimation(.spring()) { editing = false }
                    layout.save()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                }
            } else {
                Spacer(minLength: 0)
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                Button { withAnimation { showSwitcher = true } } label: {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.leading, 12)
                }
            }
        }
    }
    
    private var wallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.28),
                    Color(red: 0.14, green: 0.22, blue: 0.42),
                    Color(red: 0.05, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(Color.blue.opacity(0.18)).frame(width: 280, height: 280).blur(radius: 50).offset(x: -90, y: -160)
            Circle().fill(Color.purple.opacity(0.14)).frame(width: 260, height: 260).blur(radius: 50).offset(x: 110, y: 180)
        }
    }
    
    private func todayPage(width: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
                widgetCard("Apps", "\(sharedModel.apps.count) installed", "square.grid.2x2.fill")
                widgetCard("Search", "Swipe down on Home", "magnifyingglass")
                widgetCard("Edit", "Touch & hold Home to rearrange", "hand.tap.fill")
                if sideStoreAvailable {
                    widgetCard("SideStore", "Open from Dock", "arrow.down.app.fill")
                }
            }
            .padding(.horizontal, SBMetrics.hPadding)
            .frame(maxWidth: width, alignment: .leading)
        }
    }
    
    private func widgetCard(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func iconPage(_ keys: [String], iconSide: CGFloat, width: CGFloat) -> some View {
        let spacing = max(8, (width - SBMetrics.hPadding * 2 - iconSide * CGFloat(SBMetrics.columns)) / CGFloat(SBMetrics.columns - 1))
        let columns = Array(repeating: GridItem(.fixed(iconSide), spacing: spacing), count: SBMetrics.columns)
        
        return ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: SBMetrics.vIconSpacing) {
                ForEach(keys, id: \.self) { k in
                    if let app = appsByKey[k] {
                        appIconCell(app: app, key: k, iconSide: iconSide)
                    }
                }
                ForEach(layout.folders) { folder in
                    folderCell(folder, iconSide: iconSide)
                }
            }
            .padding(.horizontal, SBMetrics.hPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: width)
        }
    }
    
    private func appIconCell(app: LCAppModel, key: String, iconSide: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LCSpringBoardHomeIcon(
                app: app,
                iconSide: iconSide,
                jiggling: editing,
                isLaunching: launchingId == key
            ) {
                if editing { return }
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
                    } label: { Label("New Folder", systemImage: "folder.badge.plus") }
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
                        .foregroundStyle(.white, .gray)
                        .font(.system(size: 18))
                        .offset(x: -4, y: -4)
                }
            }
        }
        .frame(width: iconSide, alignment: .top)
    }
    
    private func folderCell(_ folder: LCSpringBoardFolder, iconSide: CGFloat) -> some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: SBMetrics.cornerRadius(for: iconSide), style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: iconSide, height: iconSide)
                Image(systemName: "folder.fill")
                    .font(.system(size: iconSide * 0.42))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .rotationEffect(.degrees(editing ? 2.2 : 0))
            .animation(editing ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: editing)
            Text(folder.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSide + 8, height: SBMetrics.labelHeight, alignment: .top)
        }
        .frame(width: iconSide)
        .onTapGesture {
            if !editing { openFolderId = folder.id }
        }
    }
    
    private func dockBar(iconSide: CGFloat) -> some View {
        HStack(spacing: 18) {
            if sideStoreAvailable {
                sideStoreIcon(iconSide: iconSide)
            }
            ForEach(layout.dock, id: \.self) { k in
                if let app = appsByKey[k] {
                    appIconCell(app: app, key: k, iconSide: iconSide)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, SBMetrics.dockInnerH)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }
    
    private func sideStoreIcon(iconSide: CGFloat) -> some View {
        VStack(spacing: 5) {
            Group {
                if let img = BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(false) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: SBMetrics.cornerRadius(for: iconSide), style: .continuous)
                        .fill(Color.blue.opacity(0.35))
                        .overlay(Image(systemName: "arrow.down.app.fill").foregroundStyle(.white))
                }
            }
            .frame(width: iconSide, height: iconSide)
            .clipShape(RoundedRectangle(cornerRadius: SBMetrics.cornerRadius(for: iconSide), style: .continuous))
            .rotationEffect(.degrees(editing ? 2.2 : 0))
            .animation(editing ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: editing)
            
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
            layout.dock = Array(keys.prefix(3))
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
            try? await Task.sleep(nanoseconds: 100_000_000)
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

// MARK: - Home icon (tight mask, no white border)

struct LCSpringBoardHomeIcon: View {
    @ObservedObject var app: LCAppModel
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    @ObservedObject private var theme = LCTheme.shared
    var iconSide: CGFloat = 60
    var jiggling: Bool
    var isLaunching: Bool
    var onLaunch: () -> Void
    
    private var radius: CGFloat { SBMetrics.cornerRadius(for: iconSide) }
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Base only shows if image missing — avoid white plate under icon
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.accent.opacity(0.22))
                
                if let img = app.appInfo.iconIsDarkIcon(darkModeIcon) {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        // Overscale ~4% so any residual template padding is clipped away
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
            .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
            .scaleEffect(isLaunching ? 1.08 : 1)
            .rotationEffect(.degrees(jiggling ? 2.2 : 0))
            .animation(
                jiggling ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .spring(response: 0.3, dampingFraction: 0.7),
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

// MARK: - Search / Switcher / Folder

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
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                    Button("Cancel", action: onDismiss)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 56)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { _, app in
                            Button {
                                onLaunch(app); onDismiss()
                            } label: {
                                HStack {
                                    Text(app.displayName).foregroundStyle(.primary)
                                    Spacer()
                                    Text(app.bundleIdentifier ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        ForEach(folders.filter { query.isEmpty || $0.name.lowercased().contains(query.lowercased()) }) { folder in
                            Button { onOpenFolder(folder.id) } label: {
                                Label(folder.name, systemImage: "folder.fill").padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct LCSpringBoardSwitcherView: View {
    let apps: [LCAppModel]
    var onSelect: (LCAppModel) -> Void
    var onDismiss: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 12) {
                Capsule().fill(Color.white.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 10)
                Text("App Switcher").font(.headline).foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(apps.prefix(12).enumerated()), id: \.offset) { _, app in
                            Button { onSelect(app) } label: {
                                VStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 140, height: 240)
                                        .overlay(Text(app.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.white).padding(), alignment: .bottom)
                                    Text(app.displayName).font(.caption).foregroundStyle(.white).lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Button("Close Switcher", action: onDismiss).foregroundStyle(.white).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.85)).ignoresSafeArea(edges: .bottom))
        }
    }
}

struct LCSpringBoardFolderOverlay: View {
    let folder: LCSpringBoardFolder
    let appsByKey: [String: LCAppModel]
    var iconSide: CGFloat = 60
    var jiggling: Bool
    var onLaunch: (LCAppModel) -> Void
    var onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                Text(folder.name).font(.title2.weight(.bold)).foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: iconSide), spacing: 16)], spacing: 16) {
                    ForEach(folder.appBundleIds, id: \.self) { key in
                        if let app = appsByKey[key] {
                            LCSpringBoardHomeIcon(app: app, iconSide: iconSide, jiggling: jiggling, isLaunching: false) {
                                onLaunch(app); onClose()
                            }
                        }
                    }
                }
                .padding()
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(28)
        }
    }
}
