//
//  HeroLogoRow.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/8/25.
//


import SwiftUI

struct HeroLogoRow: View {
    var height: CGFloat = 80

    var body: some View {
        HStack {
            Spacer()
            Image("nexusStack_logo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .accessibilityHidden(true)
            Spacer()
                .allowsHitTesting(false)   // ← makes the overlay ignore touches
        }
        .padding(.vertical, 0)       // real top/bottom padding
        .padding(.horizontal, 0)    // align with nav margins
        .background(.clear)
    }
    
}
