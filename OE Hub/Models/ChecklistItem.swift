import Foundation
import SwiftData

@Model
final class ChecklistItem {
    /// Item title.
    var title: String

    /// Completion state & date.
    var isCompleted: Bool = false
    var completionDate: Date? = nil

    /// Stored priority token. Keep as string for schema stability.
    /// Expected values: "Green", "Red", "Yellow"
    var priority: String = "Green"

    /// Owning job (inverse set on `Job.checklistItems`).
    var job: Job?

    init(title: String) {
        self.title = title
    }
}

// MARK: - Type-safe wrapper for priority (no schema change)
extension ChecklistItem {
    enum Priority: String, CaseIterable {
        case green  = "Green"
        case yellow = "Yellow"
        case red    = "Red"
    }

    var priorityLevel: Priority {
        get { Priority(rawValue: priority) ?? .green }
        set { priority = newValue.rawValue }
    }
}
