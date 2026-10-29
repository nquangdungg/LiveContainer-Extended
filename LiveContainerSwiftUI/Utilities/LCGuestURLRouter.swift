//
//  LCGuestURLRouter.swift
//  LiveContainerSwiftUI
//
//  When a URL's scheme matches another guest app installed in LiveContainer,
//  offer to open that app instead of the system handler.
//

import Foundation
import UIKit

struct LCGuestURLMatch {
    let app: LCAppModel
    let url: URL
}

enum LCGuestURLRouter {
    
    /// Find guest apps whose registered URL schemes match this URL.
    static func matches(for url: URL, in apps: [LCAppModel]) -> [LCGuestURLMatch] {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return [] }
        // Ignore LiveContainer's own schemes
        let ignored: Set<String> = ["livecontainer", "livecontainer2", "livecontainer3"]
        if ignored.contains(scheme) { return [] }
        
        var out: [LCGuestURLMatch] = []
        for app in apps {
            let schemes = (app.appInfo.urlSchemes() as? [String]) ?? []
            for s in schemes {
                if s.lowercased() == scheme {
                    out.append(LCGuestURLMatch(app: app, url: url))
                    break
                }
            }
        }
        return out
    }
    
    /// Present chooser if multiple / one match; launch selected guest with url.
    @MainActor
    static func handleIfGuest(
        url: URL,
        apps: [LCAppModel],
        from presenter: UIViewController?
    ) async -> Bool {
        let found = matches(for: url, in: apps)
        guard !found.isEmpty else { return false }
        
        if found.count == 1 {
            let m = found[0]
            let ok = await confirm(
                title: "Open in \(m.app.displayName)?",
                message: "This link can be opened by \(m.app.displayName) installed in LiveContainer.\n\n\(url.absoluteString)",
                confirmTitle: "Open",
                from: presenter
            )
            if ok {
                try? await m.app.runApp(urlStr: url.absoluteString)
            }
            return true
        }
        
        // Multiple apps claim the scheme
        guard let pick = await pickApp(found: found, url: url, from: presenter) else {
            return true // handled (user cancelled)
        }
        try? await pick.app.runApp(urlStr: url.absoluteString)
        return true
    }
    
    @MainActor
    private static func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        from presenter: UIViewController?
    ) async -> Bool {
        await withCheckedContinuation { cont in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                cont.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in
                cont.resume(returning: true)
            })
            topPresenter(from: presenter)?.present(alert, animated: true)
        }
    }
    
    @MainActor
    private static func pickApp(
        found: [LCGuestURLMatch],
        url: URL,
        from presenter: UIViewController?
    ) async -> LCGuestURLMatch? {
        await withCheckedContinuation { cont in
            let sheet = UIAlertController(
                title: "Open Link With…",
                message: url.absoluteString,
                preferredStyle: .actionSheet
            )
            for m in found {
                sheet.addAction(UIAlertAction(title: m.app.displayName, style: .default) { _ in
                    cont.resume(returning: m)
                })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                cont.resume(returning: nil)
            })
            if let pop = sheet.popoverPresentationController {
                pop.sourceView = topPresenter(from: presenter)?.view
                pop.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 1, height: 1)
            }
            topPresenter(from: presenter)?.present(sheet, animated: true)
        }
    }
    
    @MainActor
    private static func topPresenter(from base: UIViewController?) -> UIViewController? {
        var p = base
        if p == nil {
            p = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        }
        while let presented = p?.presentedViewController { p = presented }
        return p
    }
}
