//
//  LCSnowOverlay.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct LCSnowOverlay: View {
    let flakeCount: Int
    
    init(flakeCount: Int = 48) {
        self.flakeCount = flakeCount
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<flakeCount {
                    let seed = Double(i) * 1.618
                    let x = (seed * 97).truncatingRemainder(dividingBy: Double(size.width))
                    let speed = 28 + (seed * 13).truncatingRemainder(dividingBy: 40)
                    let y = (t * speed + seed * 50).truncatingRemainder(dividingBy: Double(size.height) + 20) - 10
                    let drift = sin(t * 0.7 + seed) * 12
                    let r = 1.5 + (seed * 3).truncatingRemainder(dividingBy: 3.5)
                    let rect = CGRect(x: x + drift, y: y, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.55 + (seed.truncatingRemainder(dividingBy: 0.35)))))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
