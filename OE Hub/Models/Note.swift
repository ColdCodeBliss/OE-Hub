import Foundation
import SwiftData

@Model
final class Note {
    /// Full note body (can be long-form text).
    var content: String

    /// Short description shown in lists. Keep as stored for backward compatibility.
    var summary: String

    /// Index into your app’s color palette.
    var colorIndex: Int

    /// Creation timestamp.
    var creationDate: Date

    /// Owning job (inverse set on `Job.notes`).
    var job: Job?

    /// Designated initializer (preserves your existing schema usage).
    init(content: String, summary: String, colorIndex: Int) {
        self.content = content
        self.summary = summary
        self.colorIndex = colorIndex
        self.creationDate = Date()
    }

    /// Convenience init: auto-generate a short summary from content (no schema change).
    convenience init(content: String, colorIndex: Int, summaryMax: Int = 80) {
        let autoSummary = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(summaryMax)
        self.init(content: content, summary: String(autoSummary), colorIndex: colorIndex)
    }
}
