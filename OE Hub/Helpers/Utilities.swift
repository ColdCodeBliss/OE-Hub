//
//  Utilities.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/7/25.
//

import Foundation
import SwiftUI

/// Shared utility functions for the app.
func color(for colorCode: String?) -> Color {
    switch colorCode?.lowercased() {
    case "red": return .red
    case "blue": return .blue
    case "green": return .green
    case "yellow": return .yellow
    case "orange": return .orange
    case "purple": return .purple
    case "pink": return .pink
    case "teal": return .teal
    default: return .gray
    }
}
