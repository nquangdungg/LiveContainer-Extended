//
//  LCDeveloperMode.swift
//  LiveContainerSwiftUI
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LCDeveloperMode: ObservableObject {
    static let shared = LCDeveloperMode()
    
    private let enabledKey = "LCDeveloperModeEnabled"
    private let pendingKey = "LCDeveloperModePendingEnable"
    private let justEnabledKey = "LCDeveloperModeJustEnabled"
    
    @Published private(set) var isEnabled: Bool
    @Published var showEnabledBanner: Bool = false
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        // After restart requested by enable flow
        if UserDefaults.standard.bool(forKey: justEnabledKey) {
            UserDefaults.standard.set(false, forKey: justEnabledKey)
            if isEnabled {
                showEnabledBanner = true
            }
        }
        // Apply pending enable after restart
        if UserDefaults.standard.bool(forKey: pendingKey) {
            UserDefaults.standard.set(false, forKey: pendingKey)
            UserDefaults.standard.set(true, forKey: enabledKey)
            UserDefaults.standard.set(true, forKey: justEnabledKey)
            isEnabled = true
            showEnabledBanner = true
        }
    }
    
    /// User confirmed enable → persist pending → caller restarts app.
    func requestEnableAndRestart() {
        UserDefaults.standard.set(true, forKey: pendingKey)
        // Soft restart: suspend and exit so SpringBoard relaunches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                exit(0)
            }
        }
    }
    
    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        UserDefaults.standard.set(false, forKey: pendingKey)
        UserDefaults.standard.set(false, forKey: justEnabledKey)
    }
    
    func dismissBanner() {
        showEnabledBanner = false
    }
}
