import SwiftUI

struct NavLogoInset: View {
    var body: some View {
        HStack {
            Spacer()
            Image("nexusStack_logo")
                .renderingMode(.original)        // ← apply to Image itself
                .resizable()
                .aspectRatio(contentMode: .fit)  // or .scaledToFit()
                .frame(width: 50, height: 50)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .padding(.trailing, 16)  // align with trailing margin of the + button
        .padding(.top, 1)        // small breathing room
    }
}
