//
//  LCAppLockView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct LCAppLockView: View {
    @ObservedObject private var lock = LCAppLockManager.shared
    @ObservedObject private var theme = LCTheme.shared
    @State private var digits: String = ""
    @State private var errorShake = false
    @State private var message: String = "Enter Passcode"
    
    var body: some View {
        ZStack {
            theme.pageBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer(minLength: 40)
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("LiveContainer Extended")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                
                HStack(spacing: 14) {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .strokeBorder(theme.accent.opacity(0.5), lineWidth: 1.5)
                            .background(
                                Circle().fill(i < digits.count ? theme.accent : Color.clear)
                            )
                            .frame(width: 14, height: 14)
                    }
                }
                .modifier(LCShakeEffect(shakes: errorShake ? 2 : 0))
                
                if lock.biometricsAllowed && lock.biometricsAvailable {
                    Button {
                        Task {
                            _ = await lock.unlockWithBiometrics()
                        }
                    } label: {
                        Label("Unlock with \(lock.biometricsLabel)", systemImage: lock.biometricsLabel == "Face ID" ? "faceid" : "touchid")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                numpad
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            Task {
                if lock.biometricsAllowed {
                    _ = await lock.unlockWithBiometrics()
                }
            }
        }
    }
    
    private var numpad: some View {
        let keys: [[String]] = [
            ["1","2","3"],
            ["4","5","6"],
            ["7","8","9"],
            ["","0","⌫"]
        ]
        return VStack(spacing: 12) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKey(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                .frame(width: 76, height: 76)
                                .background(
                                    Circle().fill(key.isEmpty ? Color.clear : Color.primary.opacity(0.08))
                                )
                        }
                        .disabled(key.isEmpty)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func handleKey(_ key: String) {
        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }
        guard digits.count < 6 else { return }
        digits.append(key)
        if digits.count == 6 {
            if lock.verifyPasscode(digits) {
                message = "Unlocked"
            } else {
                message = "Wrong passcode"
                errorShake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    errorShake = false
                    digits = ""
                }
            }
        }
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

/// Settings section to enable / change app lock
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
                Button("Change Passcode") {
                    showSet = true
                    step = 0
                    newCode = ""
                    confirmCode = ""
                    err = ""
                }
            }
        } header: {
            Text("App Lock")
        } footer: {
            Text("When enabled, Face ID / Touch ID or a 6-digit passcode is required every time you open LiveContainer Extended. Passcode is stored only in the device Keychain.")
        }
        .sheet(isPresented: $showSet) {
            NavigationView {
                VStack(spacing: 16) {
                    Text(step == 0 ? "Enter a new 6-digit passcode" : "Confirm passcode")
                        .font(.headline)
                    SecureField("••••••", text: step == 0 ? $newCode : $confirmCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    if !err.isEmpty {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                    Button(step == 0 ? "Continue" : "Save") {
                        if step == 0 {
                            guard newCode.count == 6, newCode.allSatisfy(\.isNumber) else {
                                err = "Passcode must be 6 digits"
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
                    Spacer()
                }
                .padding(.top, 40)
                .navigationTitle("App Lock")
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
