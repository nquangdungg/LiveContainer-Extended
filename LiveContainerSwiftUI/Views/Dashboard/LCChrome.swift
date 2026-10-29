//
//  LCChrome.swift
//  LiveContainerSwiftUI
//
//  Shared Extended chrome (iOS 15+ safe)
//

import SwiftUI
import UIKit

struct LCChromeHeader: View {
    @ObservedObject private var theme = LCTheme.shared
    var title: String
    var accentWord: String? = "Extended"
    /// Secondary English tag (e.g. "Fork") — opposite color of accent
    var secondaryTag: String? = "Fork"
    var subtitle: String?
    var trailing: AnyView? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                if let accentWord {
                    Text(accentWord)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
                
                if let secondaryTag {
                    Text(secondaryTag)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accentOpposite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accentOpposite.opacity(0.14))
                        .clipShape(Capsule())
                }
                
                Spacer(minLength: 0)
                if let trailing { trailing }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LCChromePageBackground: View {
    @ObservedObject private var theme = LCTheme.shared
    var body: some View {
        theme.pageBackground.ignoresSafeArea()
    }
}

struct LCHideListBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content.onAppear {
                UITableView.appearance().backgroundColor = .clear
            }
            .onDisappear {
                UITableView.appearance().backgroundColor = nil
            }
        }
    }
}

extension View {
    func lcHideListBackground() -> some View {
        modifier(LCHideListBackgroundModifier())
    }
    
    func lcChromeListStyle() -> some View {
        self.listStyle(.insetGrouped).lcHideListBackground()
    }
}
