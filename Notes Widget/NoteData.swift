import Foundation

// MARK: - Model

/// Codable representation of a single note, persisted to disk.
struct NoteData: Codable {
    var id = UUID()
    var rtf = Data()
    var rgba: [CGFloat] = [1.0, 0.92, 0.45, 1.0]
    var frame: [CGFloat] = [300, 300, 260, 220]
}
