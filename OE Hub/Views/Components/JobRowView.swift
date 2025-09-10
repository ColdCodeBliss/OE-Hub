import SwiftUI
import SwiftData

struct JobRowView: View {
    let job: Job

    // Classic (fallback) and Beta (real Liquid Glass) toggles
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let radius: CGFloat = 20

    var body: some View {
        let tint = color(for: job.colorCode)

        VStack(alignment: .leading, spacing: 8) {
            Text(job.title)
                .font(.headline)

            Text("Created: \(job.creationDate, format: .dateTime.day().month().year())")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(activeItemsCount(job)) active items")
                .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(tint: tint))                     // ← bubble styles here
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        // “Floating bubble” shadow
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        .padding(.vertical, 2)
    }

    // MARK: - Backgrounds (Beta → real Liquid Glass; Classic → material; else solid)

    @ViewBuilder
    private func cardBackground(tint: Color) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            // ✅ Real Liquid Glass (iOS 18+)
            ZStack {
                Color.clear
                    .glassEffect(
                        .regular.tint(tint.opacity(0.75)),
                        in: .rect(cornerRadius: radius)
                    )
                // soft highlight for depth (keeps “bubble” vibe)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
        } else if isLiquidGlassEnabled {
            // 🌈 Classic glassy fallback (SDK-safe)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                )
        } else {
            // 🎨 Original solid/tinted look
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint)
        }
    }

    private var borderColor: Color {
        (isBetaGlassEnabled || isLiquidGlassEnabled)
        ? .white.opacity(0.10)
        : .black.opacity(0.06)
    }

    private var shadowColor: Color {
        (isBetaGlassEnabled || isLiquidGlassEnabled)
        ? .black.opacity(0.25)
        : .black.opacity(0.15)
    }

    private var shadowRadius: CGFloat { (isBetaGlassEnabled || isLiquidGlassEnabled) ? 14 : 5 }
    private var shadowY: CGFloat { (isBetaGlassEnabled || isLiquidGlassEnabled) ? 8 : 0 }

    // MARK: - Helpers

    private func activeItemsCount(_ job: Job) -> Int {
        let activeDeliverables = job.deliverables.filter { !$0.isCompleted }.count
        let activeChecklistItems = job.checklistItems.filter { !$0.isCompleted }.count
        return activeDeliverables + activeChecklistItems
    }
}
