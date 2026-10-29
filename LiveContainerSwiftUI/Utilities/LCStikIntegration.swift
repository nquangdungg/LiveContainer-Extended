//
//  LCStikIntegration.swift
//  LiveContainerSwiftUI
//
//  Clean StikDebug integration (URL + pairing). No StikJIT framework embed.
//

import Foundation
import UIKit

@MainActor
final class LCStikIntegration: ObservableObject {
    static let shared = LCStikIntegration()
    
    private let defaults = UserDefaults.standard
    
    @Published private(set) var pairingStatusText: String = "No pairing file"
    @Published private(set) var isInstalled: Bool = false
    
    private init() {
        refreshStatus()
    }
    
    // MARK: - Paths
    
    private var stikDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StikDebug", isDirectory: true)
    }
    
    var pairingFileURL: URL {
        stikDirectory.appendingPathComponent("pairingFile.plist")
    }
    
    var hasPairingFile: Bool {
        FileManager.default.fileExists(atPath: pairingFileURL.path)
    }
    
    // MARK: - Status
    
    func refreshStatus() {
        isInstalled = UIApplication.shared.canOpenURL(URL(string: "stikdebug://")!)
        if hasPairingFile {
            pairingStatusText = "Imported"
        } else {
            pairingStatusText = "No pairing file"
        }
    }
    
    // MARK: - Pairing
    
    @discardableResult
    func importPairingFile(from source: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: stikDirectory, withIntermediateDirectories: true)
        
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        
        let data = try Data(contentsOf: source)
        guard data.count > 32 else {
            throw NSError(domain: "LCStikDebug", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Pairing file looks empty or invalid."
            ])
        }
        
        let tmp = pairingFileURL.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if fm.fileExists(atPath: pairingFileURL.path) {
            try fm.removeItem(at: pairingFileURL)
        }
        try fm.moveItem(at: tmp, to: pairingFileURL)
        refreshStatus()
        return pairingFileURL
    }
    
    func clearPairingFile() throws {
        if FileManager.default.fileExists(atPath: pairingFileURL.path) {
            try FileManager.default.removeItem(at: pairingFileURL)
        }
        refreshStatus()
    }
    
    // MARK: - Enable JIT (stikdebug:// only)
    
    /// Official URL: stikdebug://enable-jit?bundle-id=&pid=
    func makeEnableJITURL(bundleId: String, pid: Int32, scriptName: String? = "universal.js") -> URL? {
        var c = URLComponents()
        c.scheme = "stikdebug"
        c.host = "enable-jit"
        var items = [
            URLQueryItem(name: "bundle-id", value: bundleId),
            URLQueryItem(name: "pid", value: String(pid))
        ]
        if let scriptName, !scriptName.isEmpty {
            items.append(URLQueryItem(name: "script-name", value: scriptName))
        }
        c.queryItems = items
        return c.url
    }
    
    @discardableResult
    func openEnableJIT(bundleId: String? = nil, pid: Int32? = nil) async -> Bool {
        let id = bundleId ?? Bundle.main.bundleIdentifier ?? ""
        let processId = pid ?? getpid()
        guard let url = makeEnableJITURL(bundleId: id, pid: processId) else { return false }
        return await UIApplication.shared.open(url)
    }
}
