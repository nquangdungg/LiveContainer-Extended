//
//  LCInfoPlistEditorView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct LCInfoPlistEditorView: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @State private var text: String = ""
    @State private var error: String?
    @State private var saved = false
    @Environment(\.dismiss) private var dismiss
    
    private var plistURL: URL? {
        guard let path = appModel.appInfo.bundlePath() else { return nil }
        return URL(fileURLWithPath: path).appendingPathComponent("Info.plist")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(8)
            }
            if saved {
                Text("Saved. Restart the guest app for changes to apply.")
                    .font(.footnote)
                    .foregroundStyle(theme.accent)
                    .padding(8)
            }
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
        }
        .navigationTitle("Info.plist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear(perform: load)
    }
    
    private func load() {
        guard let url = plistURL else {
            error = "Bundle path not found"
            return
        }
        // Prefer XML representation
        if let dict = NSDictionary(contentsOf: url) {
            do {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: dict,
                    format: .xml,
                    options: 0
                )
                text = String(data: data, encoding: .utf8) ?? ""
            } catch {
                self.error = error.localizedDescription
            }
        } else if let data = try? Data(contentsOf: url),
                  let s = String(data: data, encoding: .utf8) {
            text = s
        } else {
            error = "Could not read Info.plist"
        }
    }
    
    private func save() {
        guard let url = plistURL else { return }
        guard let data = text.data(using: .utf8) else {
            error = "Invalid UTF-8"
            return
        }
        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
            let out = try PropertyListSerialization.data(fromPropertyList: obj, format: .xml, options: 0)
            try out.write(to: url, options: .atomic)
            saved = true
            error = nil
        } catch {
            self.error = "Save failed: \(error.localizedDescription)"
            saved = false
        }
    }
}

struct LCAppIconPickerView: View {
    @ObservedObject var appModel: LCAppModel
    @ObservedObject private var theme = LCTheme.shared
    @State private var picking = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    iconPreview
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Button("Choose Image…") { picking = true }
                Button("Reset to Original", role: .destructive) {
                    resetIcon()
                }
            } footer: {
                Text("Custom icons are stored inside LiveContainer only. They do not change the iOS Home Screen icon.")
            }
            if let message {
                Section {
                    Text(message).font(.footnote).foregroundStyle(theme.secondaryText)
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .betterFileImporter(isPresented: $picking, types: [.image], multiple: false, callback: { urls in
            if let url = urls.first {
                applyIcon(from: url)
            }
        }, onDismiss: {
            picking = false
        })
    }
    
    @ViewBuilder
    private var iconPreview: some View {
        if let img = loadOverride() ?? appModel.appInfo.iconIsDarkIcon(false) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 16).fill(theme.accent.opacity(0.2))
        }
    }
    
    private var overrideURL: URL? {
        guard let path = appModel.appInfo.bundlePath() else { return nil }
        return URL(fileURLWithPath: path)
            .appendingPathComponent("LCExtendedIcon.png")
    }
    
    private func loadOverride() -> UIImage? {
        guard let url = overrideURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    
    private func applyIcon(from url: URL) {
        guard let dest = overrideURL else { return }
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data),
              let png = img.pngData() else {
            message = "Could not read image"
            return
        }
        do {
            try png.write(to: dest, options: .atomic)
            // Also try to overwrite common icon filenames for guest display
            if let bundle = appModel.appInfo.bundlePath() {
                let candidates = ["AppIcon60x60@2x.png", "icon.png", "Icon.png"]
                for name in candidates {
                    let p = URL(fileURLWithPath: bundle).appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: p.path) {
                        try? png.write(to: p, options: .atomic)
                    }
                }
            }
            message = "Icon updated. It may take a moment to refresh in the list."
            appModel.objectWillChange.send()
        } catch {
            message = error.localizedDescription
        }
    }
    
    private func resetIcon() {
        if let dest = overrideURL {
            try? FileManager.default.removeItem(at: dest)
        }
        message = "Custom icon removed. Reinstall or restore original resources if system icons were overwritten."
        appModel.objectWillChange.send()
    }
}
