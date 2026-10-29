//
//  BuiltInStikDebugAppInfo.swift
//  LiveContainer
//
//  Full StikDebug IPA embedded at Frameworks/StikDebugApp.framework (same pattern as SideStore).
//

import UIKit

final class BuiltInStikDebugAppInfo: LCAppInfo {
    static let shared = BuiltInStikDebugAppInfo()
    
    private override init() {
        super.init(bundlePath: Bundle.main.bundleURL
            .appendingPathComponent("Frameworks/StikDebugApp.framework").path)
    }
    
    /// Present in app list only when the framework was packed into the IPA.
    static var isEmbedded: Bool {
        FileManager.default.fileExists(
            atPath: Bundle.main.bundleURL
                .appendingPathComponent("Frameworks/StikDebugApp.framework")
                .path
        )
    }
    
    override func iconIsDarkIcon(_ isDarkIcon: Bool) -> UIImage! {
        if isDarkIcon {
            if let cachedIconDark { return cachedIconDark }
        } else {
            if let cachedIcon { return cachedIcon }
        }
        guard let iconCacheUrl = ensureAndGetIconCacheFolder() else { return nil }
        let cachedIconURL = iconCacheUrl.appendingPathComponent(isDarkIcon ? "LCAppIconDark.png" : "LCAppIconLight.png")
        if FileManager.default.fileExists(atPath: cachedIconURL.path),
           let ans = UIImage(contentsOfFile: cachedIconURL.path) {
            return ans
        }
        let ans = UIImage.generateIcon(
            forBundleURL: URL(fileURLWithPath: bundlePath()),
            style: isDarkIcon ? .Dark : .Light,
            hasBorder: true
        )
        if let ans, let cg = ans.cgImage {
            saveCGImage(cg, cachedIconURL)
        }
        if isDarkIcon { cachedIconDark = ans } else { cachedIcon = ans }
        return ans
    }
    
    override var lastLaunched: Date! {
        get { nil }
        set { }
    }
    
    private func ensureAndGetIconCacheFolder() -> URL? {
        let directory = LCPath.docPath
            .appendingPathComponent("StikDebug/Library/Caches", isDirectory: true)
            .appendingPathComponent("BuiltInStikDebugIconCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
