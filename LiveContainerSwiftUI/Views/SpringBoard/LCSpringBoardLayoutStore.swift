//
//  LCSpringBoardLayoutStore.swift
//  LiveContainerSwiftUI
//
//  Persists SpringBoard home pages, dock order, and folders.
//

import Foundation
import Combine

struct LCSpringBoardFolder: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var appBundleIds: [String]
}

final class LCSpringBoardLayoutStore: ObservableObject {
    static let shared = LCSpringBoardLayoutStore()
    
    private let defaults = LCUtils.appGroupUserDefault
    private let pagesKey = "LCSpringBoardPages"
    private let dockKey = "LCSpringBoardDock"
    private let foldersKey = "LCSpringBoardFolders"
    
    /// Pages of app relativeBundlePath / bundle id keys
    @Published var pages: [[String]] = [[]]
    @Published var dock: [String] = []
    @Published var folders: [LCSpringBoardFolder] = []
    
    private init() {
        load()
    }
    
    func load() {
        if let data = defaults.data(forKey: pagesKey),
           let decoded = try? JSONDecoder().decode([[String]].self, from: data),
           !decoded.isEmpty {
            pages = decoded
        } else {
            pages = [[]]
        }
        if let data = defaults.data(forKey: dockKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            dock = decoded
        }
        if let data = defaults.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([LCSpringBoardFolder].self, from: data) {
            folders = decoded
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(pages) {
            defaults.set(data, forKey: pagesKey)
        }
        if let data = try? JSONEncoder().encode(dock) {
            defaults.set(data, forKey: dockKey)
        }
        if let data = try? JSONEncoder().encode(folders) {
            defaults.set(data, forKey: foldersKey)
        }
    }
    
    /// Place any unknown apps onto the last page.
    func reconcile(with apps: [LCAppModel]) {
        let known = Set(pages.flatMap { $0 } + dock + folders.flatMap { $0.appBundleIds })
        var changed = false
        for app in apps {
            let rel = app.appInfo.relativeBundlePath ?? ""
            let bid = app.bundleIdentifier ?? ""
            let key = rel.isEmpty ? bid : rel
            guard !key.isEmpty, !known.contains(key) else { continue }
            if pages.isEmpty { pages = [[]] }
            pages[pages.count - 1].append(key)
            changed = true
        }
        if changed { save() }
    }
    
    func folder(for id: UUID) -> LCSpringBoardFolder? {
        folders.first { $0.id == id }
    }
}
