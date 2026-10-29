//
//  LCAppLockManager.swift
//  LiveContainerSwiftUI
//
//  App-level passcode / biometrics lock (Keychain-backed).
//

import Foundation
import LocalAuthentication
import Security
import SwiftUI
import Combine

@MainActor
final class LCAppLockManager: ObservableObject {
    static let shared = LCAppLockManager()
    
    private let service = "com.livecontainer.extended.applock"
    private let account = "passcode"
    private let enabledKey = "LCAppLockEnabled"
    private let biometricsKey = "LCAppLockBiometrics"
    
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
    }
    @Published var biometricsAllowed: Bool {
        didSet { UserDefaults.standard.set(biometricsAllowed, forKey: biometricsKey) }
    }
    /// When true, UI should show lock screen and block app content.
    @Published var isLocked: Bool = false
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        biometricsAllowed = UserDefaults.standard.object(forKey: biometricsKey) as? Bool ?? true
        isLocked = isEnabled && hasPasscode()
    }
    
    func hasPasscode() -> Bool {
        loadPasscode() != nil
    }
    
    func setPasscode(_ code: String) throws {
        let data = Data(code.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "LCAppLock", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to store passcode in Keychain (\(status))"
            ])
        }
        isEnabled = true
        isLocked = true
    }
    
    func clearPasscode() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        isEnabled = false
        isLocked = false
    }
    
    func verifyPasscode(_ code: String) -> Bool {
        guard let stored = loadPasscode() else { return false }
        let ok = stored == code
        if ok { isLocked = false }
        return ok
    }
    
    func lockIfNeeded() {
        if isEnabled && hasPasscode() {
            isLocked = true
        }
    }
    
    func unlockWithBiometrics() async -> Bool {
        guard biometricsAllowed, isEnabled, hasPasscode() else { return false }
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return false
        }
        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock LiveContainer Extended"
            )
            if ok { isLocked = false }
            return ok
        } catch {
            return false
        }
    }
    
    var biometricsAvailable: Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }
    
    var biometricsLabel: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }
    
    private func loadPasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
