//
//  LCStikSettingsSection.swift
//  LiveContainerSwiftUI
//
//  Full StikDebug when embedded (SideStore-style); pairing + enable JIT helpers.
//

import SwiftUI
import UniformTypeIdentifiers

struct LCStikSettingsSection: View {
    @ObservedObject private var stik = LCStikIntegration.shared
    @ObservedObject private var theme = LCTheme.shared
    @State private var picking = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    private var embedded: Bool { BuiltInStikDebugAppInfo.isEmbedded }
    
    var body: some View {
        Section {
            HStack {
                Text("Built-in StikDebug")
                Spacer()
                Text(embedded ? "Embedded" : "Not in this IPA")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(embedded ? theme.success : theme.secondaryText)
            }
            
            if embedded {
                Button {
                    Task { await LCUtils.openBuiltInStikDebug() }
                } label: {
                    Label("Open StikDebug", systemImage: "bolt.circle.fill")
                }
            }
            
            HStack {
                Text("Pairing file")
                Spacer()
                Text(stik.pairingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(stik.hasPairingFile ? theme.success : theme.secondaryText)
            }
            
            Button { picking = true } label: {
                Label("Import Pairing File…", systemImage: "doc.badge.plus")
            }
            
            if stik.hasPairingFile {
                Button("Remove Pairing File", role: .destructive) {
                    do {
                        try stik.clearPairingFile()
                        present("Done", "Pairing file removed.")
                    } catch {
                        present("Error", error.localizedDescription)
                    }
                }
            }
            
            Button {
                Task {
                    let ok = await stik.openEnableJIT()
                    present("StikDebug", ok ? "Sent enable-JIT request." : "Could not open StikDebug URL.")
                }
            } label: {
                Label("Request Enable JIT", systemImage: "bolt.fill")
            }
        } header: {
            Text("StikDebug")
        } footer: {
            Text(embedded
                 ? "This build includes the full StikDebug app (embedded like SideStore). Open it from here or run it as a guest. iOS 17.4+, LocalDevVPN, and a pairing file are still required for JIT."
                 : "This IPA has no embedded StikDebug. Install StikDebug separately, or build LiveContainer+StikDebug.ipa from CI.")
        }
        .onAppear { stik.refreshStatus() }
        .betterFileImporter(
            isPresented: $picking,
            types: [UTType(filenameExtension: "mobiledevicepairing") ?? .data, .data, .item],
            multiple: false,
            callback: { urls in
                guard let url = urls.first else { return }
                do {
                    _ = try stik.importPairingFile(from: url)
                    present("Done", "Pairing file imported.")
                } catch {
                    present("Error", error.localizedDescription)
                }
            },
            onDismiss: { picking = false }
        )
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func present(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
