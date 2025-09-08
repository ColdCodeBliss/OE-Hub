import SwiftUI

struct NavLogoInset: View {
    var body: some View {
        Image("nexusStack_logo")
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)    // tweak 24–32 if you like
            .renderingMode(.original)        // keep the asset’s colors
            .accessibilityHidden(true)
            .allowsHitTesting(false)         // never intercept taps/scroll
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 16)          // visually aligns with the + button’s trailing margin
            .padding(.top, 2)                // a touch of breathing room
    }
}
