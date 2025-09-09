import Foundation
import SwiftData

@Model
final class Job {
    // Core
    var title: String
    var creationDate: Date
    var isDeleted: Bool = false
    var deletionDate: Date? = nil

    // Relations
    @Relationship(deleteRule: .cascade, inverse: \Deliverable.job)
    var deliverables: [Deliverable] = []

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.job)
    var checklistItems: [ChecklistItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Note.job)
    var notes: [Note] = []

    // Info
    var email: String?
    var payRate: Double = 0.0
    var payType: String? = "Hourly"        // Stored string; see `compensation` wrapper below.
    var managerName: String?
    var roleTitle: String?
    var equipmentList: String?
    var jobType: String? = "Full-time"     // Stored string; see `type` wrapper below.
    var contractEndDate: Date?
    var colorCode: String? = "green"       // Stored string; see `color` wrapper below.

    init(title: String) {
        self.title = title
        self.creationDate = Date()
    }
}

// MARK: - Type-safe wrappers & helpers (no schema change)
extension Job {
    enum ColorCode: String, CaseIterable {
        case gray, red, blue, green, purple, orange, yellow, teal, pink
    }

    enum JobType: String, CaseIterable {
        case partTime   = "Part-time"
        case fullTime   = "Full-time"
        case temporary  = "Temporary"
        case contracted = "Contracted"
    }

    enum PayType: String, CaseIterable {
        case hourly = "Hourly"
        case yearly = "Yearly"
    }

    /// Type-safe accessors that read/write your stored strings.
    var color: ColorCode {
        get { ColorCode(rawValue: colorCode ?? "green") ?? .green }
        set { colorCode = newValue.rawValue }
    }

    var type: JobType {
        get { JobType(rawValue: jobType ?? "Full-time") ?? .fullTime }
        set { jobType = newValue.rawValue }
    }

    var compensation: PayType {
        get { PayType(rawValue: payType ?? "Hourly") ?? .hourly }
        set { payType = newValue.rawValue }
    }

    /// Handy derived metric for lists & badges (kept out of storage).
    var activeItemsCount: Int {
        deliverables.filter { !$0.isCompleted }.count
        + checklistItems.filter { !$0.isCompleted }.count
    }
}
