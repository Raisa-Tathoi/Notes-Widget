import Foundation

// MARK: - Store

/// Central registry of all open notes. Handles loading, creating, removing,
/// and debounced persistence to disk.
final class NoteStore {
    static let shared = NoteStore()
    private(set) var notes: [NoteController] = []
    private var saveTimer: Timer?

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopNotes")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }

    func load() {
        let saved = (try? JSONDecoder().decode([NoteData].self, from: Data(contentsOf: url))) ?? []
        if saved.isEmpty { newNote() } else { saved.forEach { notes.append(NoteController(data: $0)) } }
    }

    @objc func newNote() {
        var d = NoteData()
        d.frame[0] += CGFloat(notes.count % 8) * 24
        d.frame[1] -= CGFloat(notes.count % 8) * 24
        notes.append(NoteController(data: d))
        scheduleSave()
    }

    func remove(_ note: NoteController) {
        notes.removeAll { $0 === note }
        save()
    }

    func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in self.save() }
    }

    func save() {
        try? JSONEncoder().encode(notes.map { $0.snapshot() }).write(to: url)
    }
}
