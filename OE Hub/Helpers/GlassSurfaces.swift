//
//  GlassSurfaces.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/24/25.
//

import SwiftUI

@available(iOS 26.0, *)
extension View {
    func glassButton() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

func color(for code: Int) -> Color {
    // Reuse your existing palette; this is a safe fallback
    let palette: [Color] = [.blue, .purple, .pink, .mint, .orange, .teal, .indigo, .red, .green, .cyan, .yellow, .brown]
    return palette[abs(code) % palette.count]
}

func tsFormattedDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "MM/dd/yyyy"
    return df.string(from: date)
}

