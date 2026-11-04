//
//  LCAppearanceEffects.swift
//  LiveContainerSwiftUI
//
//  Background ambient visual effects engine.
//

import Foundation
import SwiftUI
import Combine

enum LCParticleEffect: String, CaseIterable, Identifiable {
    case none = "None"
    case snow = "Snow"
    case rain = "Cyber Rain"
    case aurora = "Cosmic Aurora"
    case starfield = "Starfield"
    case floatingOrbs = "Floating Orbs"
    case matrix = "Digital Rain"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "slash.circle"
        case .snow: return "snowflake"
        case .rain: return "cloud.rain.fill"
        case .aurora: return "sparkles"
        case .starfield: return "star.fill"
        case .floatingOrbs: return "sun.max.fill"
        case .matrix: return "terminal.fill"
        }
    }
}

@MainActor
final class LCAppearanceEffects: ObservableObject {
    static let shared = LCAppearanceEffects()
    
    private let effectKey = "LCParticleEffect"
    
    @Published var effect: LCParticleEffect {
        didSet {
            UserDefaults.standard.set(effect.rawValue, forKey: effectKey)
            LCUtils.appGroupUserDefault.set(effect.rawValue, forKey: effectKey)
            objectWillChange.send()
        }
    }
    
    private init() {
        let store = LCUtils.appGroupUserDefault
        let raw = store.string(forKey: effectKey) ?? UserDefaults.standard.string(forKey: effectKey) ?? LCParticleEffect.none.rawValue
        self.effect = LCParticleEffect(rawValue: raw) ?? .none
    }
}
