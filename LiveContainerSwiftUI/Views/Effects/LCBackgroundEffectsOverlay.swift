//
//  LCBackgroundEffectsOverlay.swift
//  LiveContainerSwiftUI
//
//  GPU-accelerated ambient background effects: Snow, Rain, Aurora, Starfield, Floating Orbs, Digital Rain.
//

import SwiftUI

struct LCBackgroundEffectsOverlay: View {
    @ObservedObject private var effects = LCAppearanceEffects.shared
    
    var body: some View {
        Group {
            switch effects.effect {
            case .none:
                EmptyView()
            case .snow:
                LCSnowCanvas()
            case .rain:
                LCRainCanvas()
            case .aurora:
                LCAuroraCanvas()
            case .starfield:
                LCStarfieldCanvas()
            case .floatingOrbs:
                LCFloatingOrbsCanvas()
            case .matrix:
                LCMatrixRainCanvas()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Snow Effect

struct LCSnowCanvas: View {
    var flakeCount: Int = 54
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<flakeCount {
                    let seed = Double(i) * 1.61803398875
                    let x = (seed * 103).truncatingRemainder(dividingBy: Double(size.width))
                    let speed = 25.0 + (seed * 17).truncatingRemainder(dividingBy: 45.0)
                    let y = (t * speed + seed * 60).truncatingRemainder(dividingBy: Double(size.height) + 30) - 15
                    let drift = sin(t * 0.8 + seed * 2.0) * 14.0
                    let r = 1.6 + (seed * 4.2).truncatingRemainder(dividingBy: 3.5)
                    let rect = CGRect(x: x + drift, y: y, width: r, height: r)
                    let alpha = 0.45 + (seed.truncatingRemainder(dividingBy: 0.45))
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
                }
            }
        }
    }
}

// MARK: - Rain Effect

struct LCRainCanvas: View {
    var dropCount: Int = 60
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<dropCount {
                    let seed = Double(i) * 2.33
                    let x = (seed * 89).truncatingRemainder(dividingBy: Double(size.width))
                    let speed = 350.0 + (seed * 29).truncatingRemainder(dividingBy: 200.0)
                    let y = (t * speed + seed * 120).truncatingRemainder(dividingBy: Double(size.height) + 60) - 30
                    let length = 12.0 + (seed * 5).truncatingRemainder(dividingBy: 16.0)
                    
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - length * 0.25, y: y + length))
                    
                    let alpha = 0.25 + (seed.truncatingRemainder(dividingBy: 0.35))
                    context.stroke(
                        path,
                        with: .color(Color(red: 0.6, green: 0.85, blue: 1.0).opacity(alpha)),
                        lineWidth: 1.2
                    )
                }
            }
        }
    }
}

// MARK: - Cosmic Aurora Waves

struct LCAuroraCanvas: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate * 0.45
                let w = size.width
                let h = size.height
                
                // Wave 1: Cyan/Blue wave
                var path1 = Path()
                path1.move(to: CGPoint(x: 0, y: h * 0.35))
                for x in stride(from: 0.0, through: Double(w), by: 12.0) {
                    let y = h * 0.35 + sin(x * 0.008 + t) * 45.0 + cos(x * 0.004 - t * 0.5) * 25.0
                    path1.addLine(to: CGPoint(x: x, y: y))
                }
                path1.addLine(to: CGPoint(x: w, y: h))
                path1.addLine(to: CGPoint(x: 0, y: h))
                path1.closeSubpath()
                
                context.fill(
                    path1,
                    with: .linearGradient(
                        Gradient(colors: [Color.cyan.opacity(0.12), Color.blue.opacity(0.04), Color.clear]),
                        startPoint: CGPoint(x: 0, y: h * 0.3),
                        endPoint: CGPoint(x: w, y: h * 0.8)
                    )
                )
                
                // Wave 2: Purple/Pink wave
                var path2 = Path()
                path2.move(to: CGPoint(x: 0, y: h * 0.5))
                for x in stride(from: 0.0, through: Double(w), by: 12.0) {
                    let y = h * 0.5 + cos(x * 0.009 - t * 1.2) * 50.0 + sin(x * 0.005 + t * 0.7) * 30.0
                    path2.addLine(to: CGPoint(x: x, y: y))
                }
                path2.addLine(to: CGPoint(x: w, y: h))
                path2.addLine(to: CGPoint(x: 0, y: h))
                path2.closeSubpath()
                
                context.fill(
                    path2,
                    with: .linearGradient(
                        Gradient(colors: [Color.purple.opacity(0.14), Color.pink.opacity(0.05), Color.clear]),
                        startPoint: CGPoint(x: w * 0.2, y: h * 0.4),
                        endPoint: CGPoint(x: w * 0.8, y: h * 0.9)
                    )
                )
            }
        }
    }
}

// MARK: - Starfield Effect

struct LCStarfieldCanvas: View {
    var starCount: Int = 70
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<starCount {
                    let seed = Double(i) * 3.14159
                    let x = (seed * 137).truncatingRemainder(dividingBy: Double(size.width))
                    let y = (seed * 199).truncatingRemainder(dividingBy: Double(size.height))
                    let pulse = (sin(t * 1.5 + seed * 3.0) + 1.0) * 0.5
                    let r = 1.0 + (seed * 2).truncatingRemainder(dividingBy: 2.5)
                    let alpha = 0.2 + pulse * 0.7
                    
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
                }
                
                // Occasional subtle shooting star
                let shootCycle = t.truncatingRemainder(dividingBy: 7.0)
                if shootCycle < 0.8 {
                    let progress = shootCycle / 0.8
                    let startX = size.width * 0.85 - progress * 240.0
                    let startY = size.height * 0.15 + progress * 160.0
                    var shootPath = Path()
                    shootPath.move(to: CGPoint(x: startX, y: startY))
                    shootPath.addLine(to: CGPoint(x: startX + 35.0, y: startY - 24.0))
                    let shootAlpha = (1.0 - progress) * 0.65
                    context.stroke(
                        shootPath,
                        with: .color(Color.cyan.opacity(shootAlpha)),
                        lineWidth: 1.5
                    )
                }
            }
        }
    }
}

// MARK: - Floating Orbs / Fireflies

struct LCFloatingOrbsCanvas: View {
    var orbCount: Int = 32
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<orbCount {
                    let seed = Double(i) * 2.718
                    let baseX = (seed * 113).truncatingRemainder(dividingBy: Double(size.width))
                    let speed = 18.0 + (seed * 11).truncatingRemainder(dividingBy: 22.0)
                    let y = Double(size.height) - (t * speed + seed * 70).truncatingRemainder(dividingBy: Double(size.height) + 50)
                    let sway = sin(t * 1.1 + seed) * 22.0
                    let r = 4.0 + (seed * 5).truncatingRemainder(dividingBy: 8.0)
                    let pulse = (sin(t * 2.0 + seed * 2.5) + 1.0) * 0.5
                    let alpha = 0.18 + pulse * 0.4
                    
                    let rect = CGRect(x: baseX + sway - r / 2, y: y - r / 2, width: r, height: r)
                    let color = (i % 3 == 0) ? Color.orange : ((i % 3 == 1) ? Color.yellow : Color.green)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
    }
}

// MARK: - Matrix Digital Rain

struct LCMatrixRainCanvas: View {
    var streamCount: Int = 28
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<streamCount {
                    let seed = Double(i) * 5.41
                    let x = (Double(i) / Double(streamCount)) * Double(size.width) + 8.0
                    let speed = 90.0 + (seed * 19).truncatingRemainder(dividingBy: 110.0)
                    let headY = (t * speed + seed * 100).truncatingRemainder(dividingBy: Double(size.height) + 180) - 40
                    
                    let trailLength = 8
                    for step in 0..<trailLength {
                        let y = headY - Double(step * 14)
                        if y > 0 && y < Double(size.height) {
                            let rect = CGRect(x: x, y: y, width: 4.5, height: 9.0)
                            let trailAlpha = (1.0 - Double(step) / Double(trailLength)) * 0.45
                            let color = (step == 0) ? Color.white : Color(red: 0.1, green: 0.95, blue: 0.3)
                            context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color.opacity(trailAlpha)))
                        }
                    }
                }
            }
        }
    }
}
