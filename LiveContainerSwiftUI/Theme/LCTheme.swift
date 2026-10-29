//
//  LCTheme.swift
//  LiveContainerSwiftUI
//
//  LiveContainer Extended — Theme, accent, app layout
//

import SwiftUI
import UIKit
import Combine

// MARK: - Accent

enum LCAccentPreset: String, CaseIterable, Identifiable {
    case orange = "Orange"
    case blue = "Blue"
    case indigo = "Indigo"
    case teal = "Teal"
    case green = "Green"
    case pink = "Pink"
    case purple = "Purple"
    case red = "Red"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .orange: return Color(red: 1.00, green: 0.42, blue: 0.21)
        case .blue:   return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .indigo: return Color(red: 0.35, green: 0.40, blue: 0.95)
        case .teal:   return Color(red: 0.10, green: 0.72, blue: 0.68)
        case .green:  return Color(red: 0.18, green: 0.72, blue: 0.40)
        case .pink:   return Color(red: 0.92, green: 0.30, blue: 0.55)
        case .purple: return Color(red: 0.62, green: 0.35, blue: 0.95)
        case .red:    return Color(red: 0.92, green: 0.28, blue: 0.28)
        }
    }
}

// MARK: - App layout

enum LCAppLayoutMode: String, CaseIterable, Identifiable {
    case list = "List"
    case grid = "Grid"
    case compact = "Compact"
    case springboard = "SpringBoard"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .compact: return "list.bullet.rectangle"
        case .springboard: return "square.grid.3x3.fill"
        }
    }
}

// MARK: - Theme (live-updating)

final class LCTheme: ObservableObject {
    static let shared = LCTheme()
    
    private let defaults: UserDefaults = LCUtils.appGroupUserDefault
    
    @Published var accentPreset: LCAccentPreset {
        didSet {
            defaults.set(accentPreset.rawValue, forKey: "LCAccentPreset")
            objectWillChange.send()
        }
    }
    
    @Published var doubleTapStatusBarToExit: Bool {
        didSet {
            defaults.set(doubleTapStatusBarToExit, forKey: "LCDoubleTapStatusBarToExit")
        }
    }
    
    @Published var appLayout: LCAppLayoutMode {
        didSet {
            defaults.set(appLayout.rawValue, forKey: "LCAppLayoutMode")
            objectWillChange.send()
        }
    }
    
    var accent: Color { accentPreset.color }
    
    /// Rough complementary color for secondary tags (English "Fork", etc.)
    var accentOpposite: Color {
        switch accentPreset {
        case .orange: return Color(red: 0.25, green: 0.55, blue: 0.95)   // blue
        case .blue:   return Color(red: 1.00, green: 0.45, blue: 0.20)   // orange
        case .indigo: return Color(red: 0.95, green: 0.75, blue: 0.15)   // gold
        case .teal:   return Color(red: 0.92, green: 0.30, blue: 0.45)   // rose
        case .green:  return Color(red: 0.62, green: 0.35, blue: 0.95)   // purple
        case .pink:   return Color(red: 0.10, green: 0.72, blue: 0.55)   // teal
        case .purple: return Color(red: 0.18, green: 0.72, blue: 0.40)   // green
        case .red:    return Color(red: 0.10, green: 0.70, blue: 0.75)   // cyan
        }
    }
    
    var pageBackground: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
                : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        })
    }
    
    var cardBackground: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1)
                : UIColor.white
        })
    }
    
    var cardBorder: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 0, alpha: 0.06)
        })
    }
    
    var secondaryText: Color { Color(UIColor.secondaryLabel) }
    var success: Color { Color(red: 0.18, green: 0.72, blue: 0.40) }
    var warning: Color { Color(red: 0.95, green: 0.65, blue: 0.15) }
    var danger:  Color { Color(red: 0.92, green: 0.28, blue: 0.28) }
    
    private init() {
        let raw = defaults.string(forKey: "LCAccentPreset") ?? LCAccentPreset.orange.rawValue
        self.accentPreset = LCAccentPreset(rawValue: raw) ?? .orange
        
        if defaults.object(forKey: "LCDoubleTapStatusBarToExit") == nil {
            self.doubleTapStatusBarToExit = true
        } else {
            self.doubleTapStatusBarToExit = defaults.bool(forKey: "LCDoubleTapStatusBarToExit")
        }
        
        let layoutRaw = defaults.string(forKey: "LCAppLayoutMode") ?? LCAppLayoutMode.list.rawValue
        self.appLayout = LCAppLayoutMode(rawValue: layoutRaw) ?? .list
    }
    
    func setAccent(_ preset: LCAccentPreset) {
        accentPreset = preset
    }
}

// MARK: - Modifiers

struct LCCardModifier: ViewModifier {
    @ObservedObject private var theme = LCTheme.shared
    var radius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func lcCard(radius: CGFloat = 16) -> some View {
        modifier(LCCardModifier(radius: radius))
    }
}
