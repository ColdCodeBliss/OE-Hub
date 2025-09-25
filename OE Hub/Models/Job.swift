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

    @Relationship(deleteRule: .cascade, inverse: \MindNode.job)
    var mindNodes: [MindNode] = []

    // Info
    var email: String?
    var payRate: Double = 0.0
    var payType: String? = "Hourly"        // Stored string; see `compensation` wrapper below.
    var managerName: String?
    var roleTitle: String?
    var equipmentList: String?
    var jobType: String? = "Full-time"     // Stored string; see `type` wrapper below.

    var contractEndDate: Date?

    // Existing color string (kept for full backward-compat)
    var colorCode: String? = "green"

    // NEW: numeric color index for True Stack & future UI (0-based palette index)
    // Will be kept in sync with `colorCode` via the computed accessors below.
    var colorIndex: Int = 3 // 3 == "green" in the ordered palette below

    // Stable namespace for per-job settings (recent repos, etc.)
    var repoBucketKey: String = UUID().uuidString

    init(title: String) {
        self.title = title
        self.creationDate = Date()
        // make sure colorIndex matches colorCode default
        self.colorIndex = Job.ColorCode.defaultIndex
    }
}

// MARK: - Type-safe wrappers & helpers (no breaking changes)
extension Job {

    /// Ordered palette used across the app. Index = visual tint index.
    enum ColorCode: String, CaseIterable {
        case gray, red, blue, green, purple, orange, yellow, teal, brown
        // If you later expand the palette, add cases at the end to keep
        // existing indices stable.

        static let ordered: [ColorCode] = [.gray, .red, .blue, .green, .purple, .orange, .yellow, .teal, .brown]

        static var defaultIndex: Int {
            // Our stored default string is "green"
            ordered.firstIndex(of: .green) ?? 3
        }

        static func index(for raw: String?) -> Int {
            let key = raw?.lowercased() ?? "green"
            if let cc = ColorCode(rawValue: key),
               let idx = ordered.firstIndex(of: cc) {
                return idx
            }
            return defaultIndex
        }

        static func name(for index: Int) -> String {
            let idx = (index >= 0 && index < ordered.count) ? index : defaultIndex
            return ordered[idx].rawValue
        }
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

    /// Type-safe accessors that read/write your stored strings and keep `colorIndex` in sync.
    var color: ColorCode {
        get {
            // If colorIndex looks valid, prefer it (fast path).
            if (0..<ColorCode.ordered.count).contains(colorIndex) {
                return ColorCode.ordered[colorIndex]
            }
            // Otherwise derive from colorCode string and also repair colorIndex.
            let idx = ColorCode.index(for: colorCode)
            colorIndex = idx
            return ColorCode.ordered[idx]
        }
        set {
            colorCode = newValue.rawValue
            colorIndex = ColorCode.ordered.firstIndex(of: newValue) ?? ColorCode.defaultIndex
        }
    }

    /// For callers that just want an Int and don’t care about strings.
    /// Always returns a valid index (repairs invalid stored values on access).
    var effectiveColorIndex: Int {
        get {
            if (0..<ColorCode.ordered.count).contains(colorIndex) {
                return colorIndex
            }
            let idx = ColorCode.index(for: colorCode)
            colorIndex = idx
            return idx
        }
        set {
            let idx = max(0, min(newValue, ColorCode.ordered.count - 1))
            colorIndex = idx
            colorCode = ColorCode.name(for: idx)
        }
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

    /// Convenience for cycling color (used by True Stack context menu, etc.)
    func cycleColorForward() {
        let next = (effectiveColorIndex + 1) % ColorCode.ordered.count
        effectiveColorIndex = next
    }
}
