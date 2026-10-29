//
//  LCAppearanceEffects.swift
//  LiveContainerSwiftUI
//

import Foundation
import SwiftUI
import Combine

enum LCParticleEffect: String, CaseIterable, Identifiable {
    case none = "None"
    case snow = "Snow"
    
    var id: String { rawValue }
}

@MainActor
final class LCAppearanceEffects: ObservableObject {
    static let shared = LCAppearanceEffects()
    
    private let effectKey = "LCParticleEffect"
    
    @Published var effect: LCParticleEffect {
        didSet {
            UserDefaults.standard.set(effect.rawValue, forKey: effectKey)
        }
    }
    
    private init() {
        let raw = UserDefaults.standard.string(forKey: effectKey) ?? LCParticleEffect.none.rawValue
        effect = LCParticleEffect(rawValue: raw) ?? .none
    }
}
