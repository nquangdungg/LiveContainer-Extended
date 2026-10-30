//
//  LCSpringBoardShellView.swift
//  LiveContainerSwiftUI
//
//  Full-screen SpringBoard-style home shell for guest apps.
//

import SwiftUI
import UIKit

struct LCSpringBoardShellView: View {
    @EnvironmentObject var sharedModel: SharedModel
    @ObservedObject private var theme = LCTheme.shared
    @ObservedObject private var layout = LCSpringBoardLayoutStore.shared
    
    @State private var pageIndex: Int = 1 // 0 = Today, 1... = icon pages
    @State private var jiggling = false
    @State private var searching = false
    @State private var showSwitcher = false
    @State private var showSettings = false
    @State private var openFolderId: UUID?
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var launchScale: CGFloat = 1
    @State private var launchingId: String?
    
    private var appsByKey: [String: LCAppModel] {
        var map: [String: LCAppModel] = [:]
        for app in sharedModel.apps {
            let k1 = app.appInfo.relativeBundlePath
            let k2 = app.bundleIdentifier
            if !k1.isEmpty { map[k1] = app }
            if !k2.isEmpty { map[k2] = app }
        }
        return map
    }
    
    var body: some View {
        ZStack {
            wallpaper.ignoresSafeArea()
            
            VStack(spacing: 0) {
                statusChrome
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                TabView(selection: $pageIndex) {
                    todayPage.tag(0)
                    ForEach(Array(layout.pages.indices), id: \.self) { idx in
                        iconPage(layout.pages[idx])
                            .tag(idx + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                dockBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            
            if searching {
                LCSpringBoardSearchView(
                    apps: sharedModel.apps,
                    folders: layout.folders,
                    onLaunch: { launch($0) },
                    onOpenFolder: { openFolderId = $0; searching = false },
                    onDismiss: { searching = false }
                )
                .transition(.opacity)
                .zIndex(20)
            }
            
            if showSwitcher {
                LCSpringBoardSwitcherView(
                    apps: sharedModel.apps,
                    onSelect: { app in
                        showSwitcher = false
                        launch(app)
                    },
                    onDismiss: { showSwitcher = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(15)
            }
            
            if let fid = openFolderId, let folder = layout.folder(for: fid) {
                LCSpringBoardFolderOverlay(
                    folder: folder,
                    appsByKey: appsByKey,
                    jiggling: jiggling,
                    onLaunch: { launch($0) },
                    onClose: { openFolderId = nil }
                )
                .zIndex(12)
            }
        }
        .onAppear {
            layout.reconcile(with: sharedModel.apps)
            if layout.dock.isEmpty {
                // Seed dock with first up to 4 apps
                layout.dock = Array(sharedModel.apps.prefix(4).map {
                    $0.appInfo.relativeBundlePath ?? $0.bundleIdentifier
                })
                if layout.pages.first?.isEmpty == true {
                    let dockSet = Set(layout.dock)
                    layout.pages = [sharedModel.apps.compactMap { app -> String? in
                        let k = (app.appInfo.relativeBundlePath.isEmpty ? app.bundleIdentifier : app.appInfo.relativeBundlePath)
                        return dockSet.contains(k) ? nil : k
                    }]
                }
                layout.save()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                LCSettingsView()
                    .environmentObject(sharedModel)
            }
        }
        .alert("Error", isPresented: $errorShow) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorInfo)
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.startLocation.y < 120 && value.translation.height > 60 {
                        withAnimation { searching = true }
                    } else if value.translation.height < -80 && abs(value.translation.width) < 80 {
                        withAnimation { showSwitcher = true }
                    }
                }
        )
    }
    
    // MARK: - Wallpaper
    
    private var wallpaper: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.18),
                Color(red: 0.12, green: 0.18, blue: 0.32),
                Color(red: 0.08, green: 0.10, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "circles.hexagongrid.fill")
                .font(.system(size: 280))
                .foregroundStyle(.white.opacity(0.04))
                .offset(y: -40)
        )
    }
    
    private var statusChrome: some View {
        HStack {
            Text(Date(), style: .time)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Button {
                withAnimation { showSwitcher = true }
            } label: {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
    
    // MARK: - Pages
    
    private var todayPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                
                widgetCard(title: "Apps", subtitle: "\(sharedModel.apps.count) installed") {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(theme.accent)
                }
                widgetCard(title: "Search", subtitle: "Swipe down on Home") {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(theme.accent)
                }
                widgetCard(title: "Switcher", subtitle: "Swipe up from Home") {
                    Image(systemName: "square.stack.3d.up")
                        .font(.largeTitle)
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func widgetCard<C: View>(title: String, subtitle: String, @ViewBuilder icon: () -> C) -> some View {
        HStack(spacing: 14) {
            icon()
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func iconPage(_ keys: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 76), spacing: 18)]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(keys, id: \.self) { key in
                    if let app = appsByKey[key] {
                        iconCell(app: app, key: key)
                    }
                }
                ForEach(layout.folders) { folder in
                    folderCell(folder)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .onLongPressGesture {
            withAnimation(.spring()) { jiggling.toggle() }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func iconCell(app: LCAppModel, key: String) -> some View {
        LCSpringBoardHomeIcon(
            app: app,
            jiggling: jiggling,
            isLaunching: launchingId == key
        ) {
            launch(app)
        }
        .contextMenu {
            Button { launch(app) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
            Button {
                // Create folder with this app
                let folder = LCSpringBoardFolder(name: "Folder", appBundleIds: [key])
                layout.folders.append(folder)
                layout.pages = layout.pages.map { $0.filter { $0 != key } }
                layout.save()
            } label: { Label("New Folder", systemImage: "folder.badge.plus") }
            if jiggling {
                Button(role: .destructive) {
                    layout.pages = layout.pages.map { $0.filter { $0 != key } }
                    layout.dock.removeAll { $0 == key }
                    layout.save()
                } label: { Label("Remove from Home", systemImage: "minus.circle") }
            }
        }
    }
    
    private func folderCell(_ folder: LCSpringBoardFolder) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 62, height: 62)
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .rotationEffect(.degrees(jiggling ? 2 : 0))
            .animation(jiggling ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: jiggling)
            Text(folder.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 72)
        }
        .onTapGesture { openFolderId = folder.id }
    }
    
    private var dockBar: some View {
        HStack(spacing: 18) {
            ForEach(layout.dock, id: \.self) { key in
                if let app = appsByKey[key] {
                    LCSpringBoardHomeIcon(app: app, jiggling: jiggling, isLaunching: launchingId == key) {
                        launch(app)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }
    
    private func launch(_ app: LCAppModel) {
        let key = (app.appInfo.relativeBundlePath.isEmpty ? app.bundleIdentifier : app.appInfo.relativeBundlePath)
        launchingId = key
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            launchScale = 1.08
        }
        Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            do {
                try await app.runApp()
            } catch {
                errorInfo = "\(error)"
                errorShow = true
            }
            launchingId = nil
            launchScale = 1
        }
    }
}

// MARK: - Home icon

struct LCSpringBoardHomeIcon: View {
    @ObservedObject var app: LCAppModel
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    @ObservedObject private var theme = LCTheme.shared
    var jiggling: Bool
    var isLaunching: Bool
    var onLaunch: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let img = app.appInfo.iconIsDarkIcon(darkModeIcon) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent.opacity(0.25))
                        .overlay(
                            Text(String(app.displayName.prefix(1)))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isLaunching ? 1.12 : 1)
            .rotationEffect(.degrees(jiggling ? 2.5 : 0))
            .animation(
                jiggling
                    ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                    : .spring(response: 0.3, dampingFraction: 0.7),
                value: jiggling || isLaunching
            )
            
            Text(app.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onLaunch)
    }
}

// MARK: - Search

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
            $0.displayName.lowercased().contains(q) ||
            $0.bundleIdentifier.lowercased().contains(q)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Cancel", action: onDismiss)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 56)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(filtered, id: \.bundleIdentifier) { app in
                            Button {
                                onLaunch(app)
                                onDismiss()
                            } label: {
                                HStack {
                                    Text(app.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(app.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        ForEach(folders.filter { query.isEmpty || $0.name.lowercased().contains(query.lowercased()) }) { folder in
                            Button {
                                onOpenFolder(folder.id)
                            } label: {
                                Label(folder.name, systemImage: "folder.fill")
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Switcher

struct LCSpringBoardSwitcherView: View {
    let apps: [LCAppModel]
    var onSelect: (LCAppModel) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 12) {
                Capsule().fill(Color.white.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 10)
                Text("App Switcher")
                    .font(.headline)
                    .foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(apps.prefix(12), id: \.bundleIdentifier) { app in
                            Button {
                                onSelect(app)
                            } label: {
                                VStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 140, height: 240)
                                        .overlay(
                                            Text(app.displayName)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .padding()
                                            , alignment: .bottom
                                        )
                                    Text(app.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Button("Close Switcher", action: onDismiss)
                    .foregroundStyle(.white)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

// MARK: - Folder overlay

struct LCSpringBoardFolderOverlay: View {
    let folder: LCSpringBoardFolder
    let appsByKey: [String: LCAppModel]
    var jiggling: Bool
    var onLaunch: (LCAppModel) -> Void
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                Text(folder.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 16)], spacing: 16) {
                    ForEach(folder.appBundleIds, id: \.self) { key in
                        if let app = appsByKey[key] {
                            LCSpringBoardHomeIcon(app: app, jiggling: jiggling, isLaunching: false) {
                                onLaunch(app)
                                onClose()
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
