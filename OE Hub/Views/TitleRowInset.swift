import SwiftUI
import UIKit

struct TitleRowInset: View {
    /// Scale for the logo relative to the system large-title cap height.
    /// Keep 1.05–1.30 for near-match; larger values are OK, but you may need a baseline nudge.
    var logoScale: CGFloat = 3

    /// Positive values move the logo *down* a bit to match the text baseline optically.
    @ScaledMetric(relativeTo: .largeTitle) private var baselineNudge: CGFloat = 2

    private var logoHeight: CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .largeTitle)
        return font.capHeight * logoScale
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(".nexusStack")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Image("nexusStack_logo")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: logoHeight)
                // Align the image's baseline to its *bottom* so it sits with the text baseline
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                // Fine-tune downwards (increase if the logo still looks a touch high)
                .offset(y: baselineNudge)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 0)
        .padding(.bottom, 2)
    }
}
