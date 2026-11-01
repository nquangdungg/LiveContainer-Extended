//
//  LCSpringBoardShellView.swift
//  LiveContainerSwiftUI — Vibe-style SpringBoard home for LiveContainer Extended
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let kSideStoreKey = "__builtin_sidestore__"

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
        ZStack {
            wallpaper.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                
                TabView(selection: $pageIndex) {
                    todayPage.tag(0)
                    ForEach(Array(layout.pages.indices), id: \.self) { idx in
                        iconPage(layout.pages[idx]).tag(idx + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: editing ? .never : .always))
                
                dockBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, editing ? 28 : 12)
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
        }, cancelHandler: { choosingIPA = false })
        .alert("Error", isPresented: $errorShow) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorInfo) }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.55)
                .onEnded { _ in
                    guard !searching else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        editing = true
                    }
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
    
    // MARK: Top bar (iPhone-like Done / + in edit mode)
    
    private var topBar: some View {
        HStack {
            if editing {
                Button {
                    choosingIPA = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.22)))
                }
                Spacer()
                Button {
                    withAnimation(.spring()) { editing = false }
                    layout.save()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                }
            } else {
                Text(Date(), style: .time)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                Button { withAnimation { showSwitcher = true } } label: {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.leading, 10)
                }
            }
        }
        .frame(height: 40)
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
            // soft orbs
            Circle().fill(Color.blue.opacity(0.18)).frame(width: 280, height: 280).blur(radius: 50).offset(x: -90, y: -160)
            Circle().fill(Color.purple.opacity(0.14)).frame(width: 260, height: 260).blur(radius: 50).offset(x: 110, y: 180)
        }
    }
    
    private var todayPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                widgetCard("Apps", "\(sharedModel.apps.count) installed", "square.grid.2x2.fill")
                widgetCard("Search", "Swipe down on Home", "magnifyingglass")
                widgetCard("Edit", "Touch & hold Home to rearrange", "hand.tap.fill")
                if sideStoreAvailable {
                    widgetCard("SideStore", "Tap Dock icon to open", "arrow.down.app.fill")
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func widgetCard(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(theme.accent)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private func iconPage(_ keys: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 76), spacing: 16)]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(keys, id: \.self) { k in
                    if let app = appsByKey[k] {
                        appIcon(app: app, key: k, inDock: false)
                    }
                }
                ForEach(layout.folders) { folder in
                    folderCell(folder)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
    
    private func appIcon(app: LCAppModel, key: String, inDock: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            LCSpringBoardHomeIcon(app: app, jiggling: editing, isLaunching: launchingId == key) {
                if editing { return }
                launch(app)
            }
            .contextMenu {
                if !editing {
                    Button { launch(app) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    Button {
                        var f = LCSpringBoardFolder(name: "Folder", appBundleIds: [key])
                        layout.folders.append(f)
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
                        .font(.system(size: 20))
                        .offset(x: -6, y: -6)
                }
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
                    .foregroundStyle(.white.opacity(0.95))
            }
            .rotationEffect(.degrees(editing ? 2.2 : 0))
            .animation(editing ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: editing)
            Text(folder.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 72)
        }
        .onTapGesture {
            if !editing { openFolderId = folder.id }
        }
    }
    
    private var dockBar: some View {
        HStack(spacing: 20) {
            // SideStore first when embedded
            if sideStoreAvailable {
                sideStoreIcon
            }
            ForEach(layout.dock.filter { $0 != kSideStoreKey }, id: \.self) { k in
                if let app = appsByKey[k] {
                    appIcon(app: app, key: k, inDock: true)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }
    
    private var sideStoreIcon: some View {
        VStack(spacing: 6) {
            Group {
                if let img = BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(false) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.35))
                        .overlay(Image(systemName: "arrow.down.app.fill").foregroundStyle(.white))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .rotationEffect(.degrees(editing ? 2.2 : 0))
            .animation(editing ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: editing)
            
            Text("SideStore")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 72)
        }
        .onTapGesture {
            guard !editing else { return }
            LCUtils.openSideStore(delegate: nil)
        }
    }
    
    private func seedLayoutIfNeeded() {
        if layout.dock.isEmpty && layout.pages == [[]] || (layout.pages.count == 1 && layout.pages[0].isEmpty) {
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
        // Reuse LCAppListView install pipeline (hidden host mounted under SpringBoard).
        NotificationCenter.default.post(
            name: NSNotification.InstallAppNotification,
            object: ["url": url]
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent.opacity(0.28))
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
                jiggling ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .spring(response: 0.3, dampingFraction: 0.7),
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

// MARK: - Search / Switcher / Folder (compact)

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
    var jiggling: Bool
    var onLaunch: (LCAppModel) -> Void
    var onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                Text(folder.name).font(.title2.weight(.bold)).foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 16)], spacing: 16) {
                    ForEach(folder.appBundleIds, id: \.self) { key in
                        if let app = appsByKey[key] {
                            LCSpringBoardHomeIcon(app: app, jiggling: jiggling, isLaunching: false) {
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
