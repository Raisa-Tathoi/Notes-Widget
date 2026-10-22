
import AppKit

// MARK: - Window

/// A borderless panel that can become key (so text editing works) but never main.
final class KeyableWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The draggable title strip at the top of a note. Dragging it moves the window.
final class DragStrip: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// The rounded, colour-filled container behind a note's contents. Reapplies its
/// background in `updateLayer()` so AppKit's layer-update cycle can't wipe the
/// colour on redraw.
final class NoteBackgroundView: NSView {
    var backgroundColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
    }
}
