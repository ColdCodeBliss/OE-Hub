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

    // Relationships
    @Relationship(inverse: \MindNode.children) var parent: MindNode?
    @Relationship(inverse: \MindNode.parent)   var children: [MindNode] = []
    @Relationship(inverse: \Job.mindNodes)     var job: Job?

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
