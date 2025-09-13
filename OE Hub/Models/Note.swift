import Foundation
import SwiftData

@Model
final class Note {
    /// Full note body (plain text; kept in sync with rich text for search/tiles)
    var content: String

    /// Short description shown in lists (backward compatible)
    var summary: String

    /// Index into your app’s color palette.
    var colorIndex: Int

    /// Creation timestamp.
    var creationDate: Date

    /// (Legacy/optional) Base64-encoded RTF payload if you previously stored it this way.
    /// Left here so we can auto-migrate it into `rtfData` the next time the note is loaded.
    var contentRTFBase64: String?

    /// Owning job (inverse set on `Job.notes`).
    var job: Job?

    /// Rich text (RTF) payload stored externally to keep the DB lean.
    @Attribute(.externalStorage) var rtfData: Data?

    // MARK: - Inits

    init(content: String, summary: String, colorIndex: Int) {
        self.content = content
        self.summary = summary
        self.colorIndex = colorIndex
        self.creationDate = Date()
    }

    convenience init(content: String, colorIndex: Int, summaryMax: Int = 80) {
        let autoSummary = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(summaryMax)
        self.init(content: content, summary: String(autoSummary), colorIndex: colorIndex)
    }

    // MARK: - Rich text bridge

    /// Bridge to rich text. Falls back to plain `content` if `rtfData` absent.
    /// Also performs one-time migration from `contentRTFBase64` if present.
    var attributed: NSAttributedString {
        get {
            // Prefer current external storage
            if let data = rtfData {
                let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.rtf
                ]
                if let s = try? NSAttributedString(data: data, options: opts, documentAttributes: nil) {
                    return s
                }
            }

            // One-time migration from legacy Base64 (if it exists)
            if let b64 = contentRTFBase64, let data = Data(base64Encoded: b64) {
                let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.rtf
                ]
                if let s = try? NSAttributedString(data: data, options: opts, documentAttributes: nil) {
                    // Migrate forward and clear legacy field
                    rtfData = data
                    contentRTFBase64 = nil
                    return s
                }
            }

            // Fallback to plain string
            return NSAttributedString(string: content)
        }
        set {
            // Keep plain string in sync for search / tiles
            content = newValue.string

            // Write RTF to external storage
            let attrs: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtf
            ]
            rtfData = try? newValue.data(
                from: NSRange(location: 0, length: newValue.length),
                documentAttributes: attrs
            )
        }
    }
}
