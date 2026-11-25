//
//  LCDashboardStatus.swift
//  LiveContainerSwiftUI
//
//  LiveContainer Extended — Certificate + LocalDevVPN status
//

import Foundation
import SwiftUI
import UIKit
import Combine
import Darwin

#if canImport(NetworkExtension)
import NetworkExtension
#endif

// MARK: - Certificate

struct LCCertificateStatus {
    enum State {
        case notImported
        case valid(daysLeft: Int, expiration: Date, teamId: String?)
        case expiringSoon(daysLeft: Int, expiration: Date, teamId: String?)
        case expired(expiration: Date, teamId: String?)
        case error(String)
    }
    
    let state: State
    
    var isImported: Bool {
        if case .notImported = state { return false }
        return true
    }
    
    var title: String {
        switch state {
        case .notImported:  return "lc.status.cert.none".loc(fallback: "No Certificate")
        case .valid:        return "lc.status.cert.valid".loc(fallback: "Certificate Valid")
        case .expiringSoon: return "lc.status.cert.expiringSoon".loc(fallback: "Expiring Soon")
        case .expired:      return "lc.status.cert.expired".loc(fallback: "Certificate Expired")
        case .error:        return "lc.status.cert.error".loc(fallback: "Certificate Error")
        }
    }
    
    var subtitle: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        switch state {
        case .notImported:
            return "lc.status.cert.importHint".loc(fallback: "Import a certificate to sign apps")
        case .valid(let days, let date, let team):
            let t = team.map { " · \($0)" } ?? ""
            return "lc.status.cert.daysLeft %lld %@".localizeWithFormat(days, df.string(from: date)) + t
        case .expiringSoon(let days, let date, let team):
            let t = team.map { " · \($0)" } ?? ""
            return "lc.status.cert.daysLeft %lld %@".localizeWithFormat(days, df.string(from: date)) + t
        case .expired(let date, let team):
            let t = team.map { " · \($0)" } ?? ""
            return "lc.status.cert.expiredOn %@".localizeWithFormat(df.string(from: date)) + t
        case .error(let msg):
            return msg
        }
    }
    
    var indicatorColor: Color {
        let theme = LCTheme.shared
        switch state {
        case .notImported: return theme.secondaryText
        case .valid: return theme.success
        case .expiringSoon: return theme.warning
        case .expired, .error: return theme.danger
        }
    }
}

// MARK: - LocalDevVPN

struct LCLocalDevVPNStatus {
    enum State {
        case connected
        case disconnected
        case connecting
        case unknown
    }
    
    let state: State
    var isConnected: Bool { state == .connected }
    
    var title: String {
        switch state {
        case .connected:    return "lc.status.vpn.connected".loc(fallback: "LocalDevVPN Connected")
        case .disconnected: return "lc.status.vpn.off".loc(fallback: "LocalDevVPN Off")
        case .connecting:   return "lc.status.vpn.connecting".loc(fallback: "LocalDevVPN Connecting…")
        case .unknown:      return "LocalDevVPN"
        }
    }
    
    var subtitle: String {
        switch state {
        case .connected:    return "lc.status.vpn.readySub".loc(fallback: "Ready to refresh apps")
        case .disconnected: return "lc.status.vpn.offSub".loc(fallback: "Turn on to enable Refresh All")
        case .connecting:   return "lc.status.vpn.connectingSub".loc(fallback: "Establishing tunnel…")
        case .unknown:      return "lc.status.vpn.unknownSub".loc(fallback: "Unable to detect status")
        }
    }
    
    var indicatorColor: Color {
        let theme = LCTheme.shared
        switch state {
        case .connected: return theme.success
        case .disconnected: return theme.secondaryText
        case .connecting: return theme.warning
        case .unknown: return theme.secondaryText
        }
    }
}

// MARK: - Manager

@MainActor
final class LCDashboardStatusManager: ObservableObject {
    static let shared = LCDashboardStatusManager()
    
    @Published var certificate = LCCertificateStatus(state: .notImported)
    @Published var localDevVPN = LCLocalDevVPNStatus(state: .disconnected)
    
    private var vpnObserver: NSObjectProtocol?
    private var bgObserver: NSObjectProtocol?
    private var fgObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?
    private var isAppActive = true
    
    private let localDevBundle = "com.jkcoxson.LocalDevVPN"
    private let localDevTunnel = "com.jkcoxson.LocalDevVPN.TunnelProv"
    
    private init() {
        refresh()
        setupLifecycleObservers()
        startPolling()
    }
    
    deinit {
        if let vpnObserver {
            NotificationCenter.default.removeObserver(vpnObserver)
        }
        if let bgObserver {
            NotificationCenter.default.removeObserver(bgObserver)
        }
        if let fgObserver {
            NotificationCenter.default.removeObserver(fgObserver)
        }
        pollTask?.cancel()
    }

    private func setupLifecycleObservers() {
        bgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isAppActive = false
                self?.pollTask?.cancel()
                self?.pollTask = nil
            }
        }
        fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isAppActive = true
                self.refresh()
                self.startPollingLoop()
            }
        }
    }
    
    func refresh() {
        refreshCertificate()
        refreshLocalDevVPN()
    }
    
    // MARK: Certificate
    
    private func refreshCertificate() {
        guard LCSharedUtils.certificatePassword() != nil,
              LCUtils.certificateData() != nil else {
            certificate = LCCertificateStatus(state: .notImported)
            return
        }
        
        // Match existing call site style in LCJITLessDiagnoseView
        LCUtils.validateCertificate { [weak self] status, date, ou, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let error, !error.isEmpty {
                    self.certificate = LCCertificateStatus(state: .error(error))
                    return
                }
                
                guard let date else {
                    if status == 0 {
                        let fallback = Date().addingTimeInterval(7 * 86400)
                        self.certificate = LCCertificateStatus(
                            state: .valid(daysLeft: 7, expiration: fallback, teamId: ou)
                        )
                    } else {
                        self.certificate = LCCertificateStatus(
                            state: .error("Unable to read certificate expiry")
                        )
                    }
                    return
                }
                
                let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
                if days < 0 {
                    self.certificate = LCCertificateStatus(state: .expired(expiration: date, teamId: ou))
                } else if days < 3 {
                    self.certificate = LCCertificateStatus(
                        state: .expiringSoon(daysLeft: max(days, 0), expiration: date, teamId: ou)
                    )
                } else {
                    self.certificate = LCCertificateStatus(
                        state: .valid(daysLeft: days, expiration: date, teamId: ou)
                    )
                }
            }
        }
    }
    
    // MARK: LocalDevVPN
    
    private func startPolling() {
        #if canImport(NetworkExtension)
        vpnObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLocalDevVPN()
            }
        }
        #endif
        
        startPollingLoop()
    }

    private func startPollingLoop() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self, self.isAppActive else { return }
                    self.refreshLocalDevVPN()
                }
            }
        }
    }
    
    private func refreshLocalDevVPN() {
        // Primary: utun interface with 10.7.x.x (LocalDevVPN tunnel range)
        if hasLocalDevVPNInterface() {
            localDevVPN = LCLocalDevVPNStatus(state: .connected)
            return
        }
        
        #if canImport(NetworkExtension)
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            Task { @MainActor in
                guard let self else { return }
                if let managers {
                    for manager in managers where self.isLocalDevVPN(manager) {
                        self.localDevVPN = LCLocalDevVPNStatus(state: self.mapStatus(manager.connection.status))
                        return
                    }
                }
                // Re-check interface (race with tunnel bring-up)
                if self.hasLocalDevVPNInterface() {
                    self.localDevVPN = LCLocalDevVPNStatus(state: .connected)
                } else {
                    self.localDevVPN = LCLocalDevVPNStatus(state: .disconnected)
                }
            }
        }
        #else
        localDevVPN = LCLocalDevVPNStatus(state: .disconnected)
        #endif
    }
    
    /// LocalDevVPN creates a utun interface in the 10.7.0.0/16 range
    private func hasLocalDevVPNInterface() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return false
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            
            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("utun") else { continue }
            guard let sa = current.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let rc = getnameinfo(
                sa,
                socklen_t(sa.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard rc == 0 else { continue }
            let ip = String(cString: host)
            if ip.hasPrefix("10.7.") {
                return true
            }
        }
        return false
    }
    
    #if canImport(NetworkExtension)
    private func isLocalDevVPN(_ manager: NEVPNManager) -> Bool {
        if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
            let provider = proto.providerBundleIdentifier ?? ""
            if provider == localDevTunnel || provider.hasPrefix(localDevBundle) {
                return true
            }
            if let server = proto.serverAddress,
               server.range(of: "LocalDevVPN", options: .caseInsensitive) != nil {
                return true
            }
        }
        if let desc = manager.localizedDescription,
           desc.range(of: "LocalDevVPN", options: .caseInsensitive) != nil {
            return true
        }
        return false
    }
    
    private func mapStatus(_ status: NEVPNStatus) -> LCLocalDevVPNStatus.State {
        switch status {
        case .connected: return .connected
        case .connecting, .reasserting: return .connecting
        case .disconnecting, .disconnected, .invalid: return .disconnected
        @unknown default: return .unknown
        }
    }
    #endif
    
    func openLocalDevVPN() {
        if let url = URL(string: "localdevvpn://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
