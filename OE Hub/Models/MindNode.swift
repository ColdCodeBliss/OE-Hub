import Foundation
import SwiftData
import SwiftUI

@Model
final class MindNode: Identifiable {
    // Identity
    var id: UUID

    // Content
    var title: String
    var isCompleted: Bool
    var colorCode: String?

    // Layout in “map space”
    var x: Double
    var y: Double
    var isRoot: Bool

    // Relationships (one-sided annotations to avoid circular macro resolution)
    var parent: MindNode?
    @Relationship(inverse: \MindNode.parent) var children: [MindNode] = []   // ← annotate only this side

    // Job owner – plain optional; inverse is defined on Job.mindNodes
    var job: Job?

    // Metadata
    var createdAt: Date

    init(title: String,
         x: Double,
         y: Double,
         colorCode: String? = nil,
         isRoot: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.colorCode = colorCode
        self.x = x
        self.y = y
        self.isRoot = isRoot
        self.createdAt = Date()
    }
}
