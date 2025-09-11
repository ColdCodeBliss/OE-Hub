//
//  Utilities.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/7/25.
//  Updated: modernized helpers, enum overloads, and readability utilities.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Core palette mapping (string token -> Color)
//
// NOTE: Keeps full compatibility with stored string values across the app.
@inlinable
func color(for colorCode: String?) -> Color {
    switch colorCode?.lowercased() {
    case "red":    return .red
    case "blue":   return .blue
    case "green":  return .green
    case "yellow": return .yellow
    case "orange": return .orange
    case "purple": return .purple
    case "brown":   return .brown
    case "teal":   return .teal
    default:       return .gray
    }
}

// MARK: - Enum overloads (type-safe, no schema change)
//
// These let you pass strongly-typed wrappers (e.g., Job.ColorCode, Deliverable.ColorCode)
// while still reusing the same string-backed palette above.

@inlinable
func color<E: RawRepresentable>(for code: E) -> Color where E.RawValue == String {
    color(for: code.rawValue)
}

// MARK: - Priority helpers

/// Optional: tint for checklist priorities (mirrors your "Green/Yellow/Red" scheme).
@inlinable
func priorityColor<P: RawRepresentable>(for priority: P) -> Color where P.RawValue == String {
    switch priority.rawValue.lowercased() {
    case "red":    return .red
    case "yellow": return .yellow
    case "green":  return .green
    case "blue":   return .blue
    case "brown":  return .brown
    case "purple": return .purple
    case "teal":   return .teal
    case "orange": return .orange
    case "gray":   return .gray
    default:       return .green
    }
}

// MARK: - Readable foreground for colored cards
//
// Chooses white or black text depending on background luminance (WCAG-ish).
@inlinable
func readableForeground(on background: Color) -> Color {
    #if canImport(UIKit)
    let ui = UIColor(background)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
        // Relative luminance approximation
        let L = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return L < 0.5 ? .white : .black
    }
    // Fallback
    return .primary
    #else
    // Non-UIKit platforms fallback
    return .primary
    #endif
}

// MARK: - Optional: Hex initializer (handy for future branding work)
//
// Not used by default, but useful if you introduce custom brand colors later.
extension Color {
    @inlinable
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
