import SwiftUI
import SwiftData

struct JobRowView: View {
    let job: Job
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(job.title)
                .font(.headline)

            Text("Created: \(job.creationDate, format: .dateTime.day().month().year())")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(activeItemsCount(job)) active items")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)                  // conditional “glass”
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Background (SDK-safe glassy look)

    @ViewBuilder
    private var backgroundView: some View {
        let tint = color(for: job.colorCode)

        if isLiquidGlassEnabled {
            // Material base + tinted overlay ≈ glass card (works on iOS 15+)
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    // gentle rim light for depth
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        } else {
            // Your previous solid/tinted look
            RoundedRectangle(cornerRadius: 12)
                .fill(tint)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.06), lineWidth: 1)
                )
        }
    }

    // MARK: - Helpers

    private func activeItemsCount(_ job: Job) -> Int {
        let activeDeliverables = job.deliverables.filter { !$0.isCompleted }.count
        let activeChecklistItems = job.checklistItems.filter { !$0.isCompleted }.count
        return activeDeliverables + activeChecklistItems
    }
}
