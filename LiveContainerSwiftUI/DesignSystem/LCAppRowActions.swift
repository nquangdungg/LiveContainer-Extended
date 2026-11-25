//
//  LCAppRowActions.swift
//  LiveContainerSwiftUI
//
//  Single source of truth for app row actions across Grid, Compact, and SpringBoard modes,
//  achieving 100% feature parity with LCAppBannerViewController (iOS 15+ safe).
//

import SwiftUI
import UIKit

struct LCAppRowActionCallbacks {
    var onRun: (Bool?) -> Void
    var onOpenSettings: () -> Void
    var onUninstall: () -> Void
    var onToggleHidden: () -> Void = {}
    var onCopyLaunchURL: (() -> Void)? = nil
    var onSaveAppIcon: (() -> Void)? = nil
    var onCreateAppClip: (() -> Void)? = nil
}

struct LCAppRowActionsModifier: ViewModifier {
    @ObservedObject var appModel: LCAppModel
    let callbacks: LCAppRowActionCallbacks

    func body(content: Content) -> some View {
        content.contextMenu {
            // 1. Containers Picker (when multiple containers exist)
            if appModel.uiContainers.count > 1 {
                Menu {
                    ForEach(appModel.uiContainers, id: \.folderName) { container in
                        Button {
                            appModel.uiSelectedContainer = container
                        } label: {
                            if container == appModel.uiSelectedContainer {
                                Label(container.name, systemImage: "checkmark")
                            } else {
                                Text(container.name)
                            }
                        }
                    }
                } label: {
                    Label("lc.common.container".loc, systemImage: "shippingbox")
                }
                Divider()
            }

            // 2. Primary Launch & Multitask
            Button {
                callbacks.onRun(false)
            } label: {
                Label("lc.appBanner.run".loc, systemImage: "play.fill")
            }

            if #available(iOS 16.0, *) {
                Button {
                    callbacks.onRun(true)
                } label: {
                    Label("lc.appBanner.multitask".loc, systemImage: "macwindow.badge.plus")
                }
            }

            // 3. Open Data Folder
            if !appModel.uiIsShared, let folderName = appModel.uiSelectedContainer?.folderName {
                Button {
                    if let url = URL(string: "shareddocuments://\(LCPath.dataPath.path)/\(folderName)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("lc.appBanner.openDataFolder".loc, systemImage: "folder")
                }
            }

            // 4. Add to Home Screen submenu (exact parity with List banner)
            Menu {
                if let relativePath = appModel.appInfo.relativeBundlePath {
                    Button {
                        let urlStr: String
                        if let folderName = appModel.uiSelectedContainer?.folderName {
                            urlStr = "livecontainer://livecontainer-launch?bundle-name=\(relativePath)&container-folder-name=\(folderName)"
                        } else {
                            urlStr = "livecontainer://livecontainer-launch?bundle-name=\(relativePath)"
                        }
                        UIPasteboard.general.string = urlStr
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        callbacks.onCopyLaunchURL?()
                    } label: {
                        Label("lc.appBanner.copyLaunchUrl".loc, systemImage: "link")
                    }
                }

                if let onSaveAppIcon = callbacks.onSaveAppIcon {
                    Button(action: onSaveAppIcon) {
                        Label("lc.appBanner.saveAppIcon".loc, systemImage: "square.and.arrow.down")
                    }
                }

                if let onCreateAppClip = callbacks.onCreateAppClip {
                    Button(action: onCreateAppClip) {
                        Label("lc.appBanner.createAppClip".loc, systemImage: "appclip")
                    }
                }
            } label: {
                Label("lc.appBanner.addToHomeScreen".loc, systemImage: "plus.app")
            }

            Divider()

            // 5. Settings & Hide/Unhide
            Button(action: callbacks.onOpenSettings) {
                Label("lc.tabView.settings".loc, systemImage: "gearshape")
            }

            Button {
                Task { await appModel.toggleHidden() }
                callbacks.onToggleHidden()
            } label: {
                Label(
                    appModel.appInfo.isHidden
                        ? "lc.appSettings.unhideApp".loc(fallback: "Unhide")
                        : "lc.appSettings.hideApp".loc,
                    systemImage: appModel.appInfo.isHidden ? "eye" : "eye.slash"
                )
            }

            // 6. Uninstall (only for non-shared apps)
            if !appModel.uiIsShared {
                Divider()
                Button(role: .destructive, action: callbacks.onUninstall) {
                    Label("lc.appBanner.uninstall".loc, systemImage: "trash")
                }
            }
        }
    }
}

extension View {
    func lcAppRowActions(appModel: LCAppModel, callbacks: LCAppRowActionCallbacks) -> some View {
        modifier(LCAppRowActionsModifier(appModel: appModel, callbacks: callbacks))
    }
}
