//
//  TitleRowInset.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/8/25.
//


import SwiftUI

struct TitleRowInset: View {
    // Keeps the logo height tracking the large title size (Dynamic Type friendly)
    @ScaledMetric(relativeTo: .largeTitle) private var logoHeight: CGFloat = 30

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(".nexusStack")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Image("nexusStack_logo")
                .renderingMode(.original)        // preserve asset colors
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: logoHeight)       // ~same visual height as the title text
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)                // align with nav bar margins
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}
