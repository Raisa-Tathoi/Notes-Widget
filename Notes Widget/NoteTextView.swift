import AppKit

// MARK: - Text View

/// An NSTextView that handles rich-text formatting shortcuts itself. The app is
/// an .accessory app with no main menu, so the usual Format-menu key equivalents
/// (⌘B/⌘I/⌘U, ⌘+/⌘−) never fire — we intercept them here instead.
final class NoteTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require Command, forbid Control/Option (but allow Shift so ⌘+ works),
        // otherwise let the text system handle the event normally.
        guard flags.contains(.command),
              !flags.contains(.control),
              !flags.contains(.option),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "b":
            toggleTrait(.boldFontMask)
            return true
        case "i":
            toggleTrait(.italicFontMask)
            return true
        case "u":
            underline(nil)
            return true
        case "+", "=":
            changeFontSize(by: 1)
            return true
        case "-":
            changeFontSize(by: -1)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    /// Adds or removes a font trait (bold/italic) on the current text. Uses
    /// NSFontManager so it correctly produces variants of the system font, which
    /// `withSymbolicTraits` fails to do.
    private func toggleTrait(_ trait: NSFontTraitMask) {
        let fm = NSFontManager.shared
        applyFontChange { font in
            if fm.traits(of: font).contains(trait) {
                return fm.convert(font, toNotHaveTrait: trait)
            } else {
                return fm.convert(font, toHaveTrait: trait)
            }
        }
    }

    /// Grows or shrinks the font size by `delta` points (clamped to a minimum).
    private func changeFontSize(by delta: CGFloat) {
        applyFontChange { font in
            let newSize = max(6, font.pointSize + delta)
            return NSFont(descriptor: font.fontDescriptor, size: newSize) ?? font
        }
    }

    /// Applies a font transform to the selected text, or to the typing attributes
    /// when nothing is selected (so the next characters typed pick up the change).
    private func applyFontChange(_ transform: (NSFont) -> NSFont) {
        let fallback = font ?? .systemFont(ofSize: 13)
        let range = selectedRange()

        if range.length == 0 {
            let current = (typingAttributes[.font] as? NSFont) ?? fallback
            typingAttributes[.font] = transform(current)
            return
        }

        guard let textStorage = textStorage,
              shouldChangeText(in: range, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, subRange, _ in
            let current = (value as? NSFont) ?? fallback
            textStorage.addAttribute(.font, value: transform(current), range: subRange)
        }
        textStorage.endEditing()
        didChangeText()
    }
}
