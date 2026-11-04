//
//  LCAppLockView.swift
//  LiveContainerSwiftUI
//
//  Modern iOS 18-style Screen Lock UI & App Lock Settings.
//

import SwiftUI
import LocalAuthentication

struct LCAppLockView: View {
    @ObservedObject private var lock = LCAppLockManager.shared
    @ObservedObject private var theme = LCTheme.shared
    
    @State private var digits: String = ""
    @State private var errorShake = false
    @State private var message: String = "Enter Passcode"
    @State private var isSuccess = false
    
    private let keyMatrix: [[(num: String, letters: String)]] = [
        [("1", ""), ("2", "A B C"), ("3", "D E F")],
        [("4", "G H I"), ("5", "J K L"), ("6", "M N O")],
        [("7", "P Q R S"), ("8", "T U V"), ("9", "W X Y Z")],
        [("bio", ""), ("0", ""), ("del", "")]
    ]
    
    var body: some View {
        ZStack {
            // Background: frosted acrylic with subtle glow
            ZStack {
                theme.pageBackground
                LinearGradient(
                    colors: [
                        theme.accent.opacity(0.12),
                        Color.clear,
                        theme.accentOpposite.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                // Padlock Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.15))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: isSuccess ? "lock.open.fill" : (lock.isLockedOut ? "lock.slash.fill" : "lock.fill"))
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(lock.isLockedOut ? theme.danger : theme.accent)
                            .scaleEffect(isSuccess ? 1.15 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSuccess)
                    }
                    
                    Text("LiveContainer")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    
                    if lock.isLockedOut {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                            Text("Try again in \(lock.lockoutSecondsRemaining)s")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.danger)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(theme.danger.opacity(0.14), in: Capsule())
                    } else {
                        Text(message)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(message == "Wrong passcode" ? theme.danger : theme.secondaryText)
                    }
                }
                
                // 6-digit Indicator Dots
                HStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .strokeBorder(
                                i < digits.count ? theme.accent : theme.secondaryText.opacity(0.4),
                                lineWidth: 2
                            )
                            .background(
                                Circle()
                                    .fill(i < digits.count ? theme.accent : Color.clear)
                            )
                            .frame(width: 15, height: 15)
                            .scaleEffect(i < digits.count ? 1.15 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: digits.count)
                    }
                }
                .padding(.vertical, 8)
                .modifier(LCShakeEffect(shakes: errorShake ? 2 : 0))
                
                Spacer()
                
                // Keypad
                numpadGrid
                    .disabled(lock.isLockedOut)
                    .opacity(lock.isLockedOut ? 0.45 : 1.0)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            if lock.biometricsAllowed && !lock.isLockedOut {
                Task {
                    _ = await lock.unlockWithBiometrics()
                }
            }
        }
    }
    
    // MARK: - Keypad Grid
    
    private var numpadGrid: some View {
        VStack(spacing: 16) {
            ForEach(0..<keyMatrix.count, id: \.self) { rowIdx in
                HStack(spacing: 24) {
                    ForEach(0..<keyMatrix[rowIdx].count, id: \.self) { colIdx in
                        let item = keyMatrix[rowIdx][colIdx]
                        keypadCell(item.num, sub: item.letters)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func keypadCell(_ key: String, sub: String) -> some View {
        if key == "bio" {
            if lock.biometricsAllowed && lock.biometricsAvailable {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { _ = await lock.unlockWithBiometrics() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 76, height: 76)
                        Image(systemName: lock.biometricsLabel == "Face ID" ? "faceid" : "touchid")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(theme.accent)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 76, height: 76)
            }
        } else if key == "del" {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if !digits.isEmpty { digits.removeLast() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 76, height: 76)
                    Image(systemName: "delete.backward")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .opacity(digits.isEmpty ? 0.3 : 1.0)
            .disabled(digits.isEmpty)
        } else {
            Button {
                handleDigitPress(key)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 76, height: 76)
                    
                    VStack(spacing: 1) {
                        Text(key)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                        if !sub.isEmpty {
                            Text(sub)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.secondaryText)
                                .tracking(1.5)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func handleDigitPress(_ digit: String) {
        guard !lock.isLockedOut else { return }
        guard digits.count < 6 else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        digits.append(digit)
        
        if digits.count == 6 {
            if lock.verifyPasscode(digits) {
                isSuccess = true
                message = "Unlocked"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                message = "Wrong passcode"
                errorShake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    errorShake = false
                    digits = ""
                }
            }
        }
    }
}

// MARK: - Privacy Shield Curtain (App Switcher Protection)

struct LCPrivacyShieldView: View {
    @ObservedObject private var theme = LCTheme.shared
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(theme.accent)
                Text("LiveContainer Extended")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(true)
    }
}

struct LCShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(shakes * .pi * 2), y: 0))
    }
}

// MARK: - Settings Section

struct LCAppLockSettingsSection: View {
    @ObservedObject private var lock = LCAppLockManager.shared
    @State private var showSet = false
    @State private var newCode = ""
    @State private var confirmCode = ""
    @State private var step = 0
    @State private var err = ""
    
    var body: some View {
        Section {
            Toggle("Require Passcode", isOn: Binding(
                get: { lock.isEnabled && lock.hasPasscode() },
                set: { on in
                    if on {
                        showSet = true
                        step = 0
                        newCode = ""
                        confirmCode = ""
                        err = ""
                    } else {
                        lock.clearPasscode()
                    }
                }
            ))
            
            if lock.isEnabled && lock.hasPasscode() {
                Toggle("Allow \(lock.biometricsLabel)", isOn: $lock.biometricsAllowed)
                    .disabled(!lock.biometricsAvailable)
                
                Picker("Auto-Lock", selection: $lock.autoLockTimeout) {
                    ForEach(LCAutoLockTimeout.allCases) { timeout in
                        Text(timeout.rawValue).tag(timeout)
                    }
                }
                
                Button("Change Passcode") {
                    showSet = true
                    step = 0
                    newCode = ""
                    confirmCode = ""
                    err = ""
                }
            }
        } header: {
            Text("Security & App Lock")
        } footer: {
            Text("Passcode is salted and hashed with SHA-256 before storing in the device Keychain. Features brute-force protection and automatic app switcher privacy shield.")
        }
        .sheet(isPresented: $showSet) {
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: step == 0 ? "key.fill" : "checkmark.shield.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 20)
                    
                    Text(step == 0 ? "Enter a new 6-digit passcode" : "Confirm your passcode")
                        .font(.headline)
                    
                    SecureField("••••••", text: step == 0 ? $newCode : $confirmCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 48)
                    
                    if !err.isEmpty {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                    
                    Button(step == 0 ? "Continue" : "Save Passcode") {
                        if step == 0 {
                            guard newCode.count == 6, newCode.allSatisfy(\.isNumber) else {
                                err = "Passcode must be 6 numeric digits"
                                return
                            }
                            step = 1
                            err = ""
                        } else {
                            guard confirmCode == newCode else {
                                err = "Passcodes do not match"
                                return
                            }
                            do {
                                try lock.setPasscode(newCode)
                                showSet = false
                            } catch {
                                err = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .navigationTitle("Set Passcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSet = false }
                    }
                }
            }
        }
    }
}
