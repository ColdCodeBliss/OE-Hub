import SwiftUI

struct HeroLogoRow: View {
    var height: CGFloat = 120

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
        }
        .padding(.vertical, 8)       // real top/bottom padding
        .padding(.horizontal, 16)    // align with nav margins
        .background(.clear)
    }
}
