//
//  LCAppLockManager.swift
//  LiveContainerSwiftUI
//
//  App-level passcode / biometrics lock (Salted SHA-256 Keychain-backed with brute-force rate limiting).
//

import Foundation
import LocalAuthentication
import Security
import SwiftUI
import Combine
import CryptoKit

enum LCAutoLockTimeout: String, CaseIterable, Identifiable {
    case immediately = "Immediately"
    case after1Minute = "1 Minute"
    case after5Minutes = "5 Minutes"
    
    var id: String { rawValue }
    
    var interval: TimeInterval {
        switch self {
        case .immediately: return 0
        case .after1Minute: return 60
        case .after5Minutes: return 300
        }
    }
}

@MainActor
final class LCAppLockManager: ObservableObject {
    static let shared = LCAppLockManager()
    
    private let service = "com.livecontainer.extended.applock"
    private let accountHash = "passcode_hash"
    private let accountSalt = "passcode_salt"
    private let legacyAccount = "passcode"
    
    private let enabledKey = "LCAppLockEnabled"
    private let biometricsKey = "LCAppLockBiometrics"
    private let timeoutKey = "LCAutoLockTimeout"
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            LCUtils.appGroupUserDefault.set(isEnabled, forKey: enabledKey)
        }
    }
    @Published var biometricsAllowed: Bool {
        didSet {
            UserDefaults.standard.set(biometricsAllowed, forKey: biometricsKey)
            LCUtils.appGroupUserDefault.set(biometricsAllowed, forKey: biometricsKey)
        }
    }
    @Published var autoLockTimeout: LCAutoLockTimeout {
        didSet {
            UserDefaults.standard.set(autoLockTimeout.rawValue, forKey: timeoutKey)
            LCUtils.appGroupUserDefault.set(autoLockTimeout.rawValue, forKey: timeoutKey)
        }
    }
    
    /// When true, UI must display screen lock overlay
    @Published var isLocked: Bool = false
    
    /// When true, renders an opaque privacy blur shield over the app during backgrounding
    @Published var isPrivacyCurtainActive: Bool = false
    
    /// Brute force lockout
    @Published var failedAttempts: Int = 0
    @Published var lockoutSecondsRemaining: Int = 0
    private var lockoutUntil: Date? = nil
    private var lockoutTimer: Timer? = nil
    
    private var lastBackgroundDate: Date? = nil
    
    private init() {
        let store = LCUtils.appGroupUserDefault
        self.isEnabled = store.object(forKey: enabledKey) as? Bool ?? UserDefaults.standard.bool(forKey: enabledKey)
        self.biometricsAllowed = store.object(forKey: biometricsKey) as? Bool ?? (UserDefaults.standard.object(forKey: biometricsKey) as? Bool ?? true)
        
        let rawTimeout = store.string(forKey: timeoutKey) ?? UserDefaults.standard.string(forKey: timeoutKey) ?? LCAutoLockTimeout.immediately.rawValue
        self.autoLockTimeout = LCAutoLockTimeout(rawValue: rawTimeout) ?? .immediately
        
        migrateLegacyPasscodeIfNeeded()
        self.isLocked = isEnabled && hasPasscode()
    }
    
    // MARK: - Passcode Management
    
    func hasPasscode() -> Bool {
        return loadPasscodeHash() != nil
    }
    
    func setPasscode(_ code: String) throws {
        guard code.count >= 4 else {
            throw NSError(domain: "LCAppLock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Passcode too short"])
        }
        
        // Generate random 16-byte salt
        var saltBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard status == errSecSuccess else {
            throw NSError(domain: "LCAppLock", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Salt generation failed"])
        }
        let salt = Data(saltBytes)
        
        // Compute SHA-256(salt + code)
        let hash = computeHash(code: code, salt: salt)
        
        // Store hash & salt in Keychain
        try storeKeychainData(hash, account: accountHash)
        try storeKeychainData(salt, account: accountSalt)
        
        // Remove any legacy plaintext passcode
        deleteKeychain(legacyAccount)
        
        resetLockout()
        isEnabled = true
        isLocked = true
    }
    
    func clearPasscode() {
        deleteKeychain(accountHash)
        deleteKeychain(accountSalt)
        deleteKeychain(legacyAccount)
        resetLockout()
        isEnabled = false
        isLocked = false
    }
    
    func verifyPasscode(_ code: String) -> Bool {
        if isLockedOut {
            return false
        }
        
        guard let storedHash = loadPasscodeHash(),
              let storedSalt = loadSalt() else {
            return false
        }
        
        let attemptHash = computeHash(code: code, salt: storedSalt)
        if attemptHash == storedHash {
            resetLockout()
            isLocked = false
            return true
        } else {
            recordFailedAttempt()
            return false
        }
    }
    
    // MARK: - Brute-force Rate Limiting
    
    var isLockedOut: Bool {
        if let until = lockoutUntil {
            if Date() < until {
                lockoutSecondsRemaining = max(1, Int(ceil(until.timeIntervalSinceNow)))
                return true
            } else {
                lockoutUntil = nil
                lockoutSecondsRemaining = 0
            }
        }
        return false
    }
    
    private func recordFailedAttempt() {
        failedAttempts += 1
        var delaySeconds: TimeInterval = 0
        if failedAttempts >= 10 {
            delaySeconds = 300 // 5 minutes
        } else if failedAttempts >= 8 {
            delaySeconds = 60  // 1 minute
        } else if failedAttempts >= 5 {
            delaySeconds = 30  // 30 seconds
        }
        
        if delaySeconds > 0 {
            let until = Date().addingTimeInterval(delaySeconds)
            lockoutUntil = until
            lockoutSecondsRemaining = Int(delaySeconds)
            startLockoutTimer()
        }
    }
    
    private func resetLockout() {
        failedAttempts = 0
        lockoutUntil = nil
        lockoutSecondsRemaining = 0
        lockoutTimer?.invalidate()
        lockoutTimer = nil
    }
    
    private func startLockoutTimer() {
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let until = self.lockoutUntil {
                    let diff = Int(ceil(until.timeIntervalSinceNow))
                    if diff > 0 {
                        self.lockoutSecondsRemaining = diff
                    } else {
                        self.resetLockout()
                    }
                } else {
                    self.resetLockout()
                }
            }
        }
    }
    
    // MARK: - App Lifecycle & Privacy Shield
    
    func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .background:
            lastBackgroundDate = Date()
            isPrivacyCurtainActive = true
            if autoLockTimeout == .immediately {
                lockIfNeeded()
            }
        case .inactive:
            isPrivacyCurtainActive = true
        case .active:
            isPrivacyCurtainActive = false
            if let last = lastBackgroundDate, autoLockTimeout != .immediately {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed >= autoLockTimeout.interval {
                    lockIfNeeded()
                }
            }
            lastBackgroundDate = nil
        @unknown default:
            break
        }
    }
    
    func lockIfNeeded() {
        if isEnabled && hasPasscode() {
            isLocked = true
        }
    }
    
    // MARK: - Biometrics
    
    func unlockWithBiometrics() async -> Bool {
        guard biometricsAllowed, isEnabled, hasPasscode(), !isLockedOut else { return false }
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
            if ok {
                resetLockout()
                isLocked = false
            }
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
    
    // MARK: - Internal Crypto & Keychain
    
    private func computeHash(code: String, salt: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: salt)
        hasher.update(data: Data(code.utf8))
        return Data(hasher.finalize())
    }
    
    private func storeKeychainData(_ data: Data, account: String) throws {
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
                NSLocalizedDescriptionKey: "Failed to write to Keychain (\(status))"
            ])
        }
    }
    
    private func loadKeychainData(account: String) -> Data? {
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
        return data
    }
    
    private func deleteKeychain(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    private func loadPasscodeHash() -> Data? {
        loadKeychainData(account: accountHash)
    }
    
    private func loadSalt() -> Data? {
        loadKeychainData(account: accountSalt)
    }
    
    private func migrateLegacyPasscodeIfNeeded() {
        if loadPasscodeHash() == nil, let legacyData = loadKeychainData(account: legacyAccount) {
            if let legacyCode = String(data: legacyData, encoding: .utf8), !legacyCode.isEmpty {
                try? setPasscode(legacyCode)
            }
        }
    }
}
