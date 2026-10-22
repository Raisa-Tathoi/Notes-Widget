import AppKit

// MARK: - Controller

/// Owns a single note's window, text view, and colour. Handles editing,
/// colour picking, deletion, and persistence of geometry changes.
final class NoteController: NSObject, NSTextViewDelegate, NSWindowDelegate {
    let id: UUID
    let window: KeyableWindow
    let textView = NoteTextView()
    var color: NSColor { didSet { applyColor() } }

    init(data: NoteData) {
        id = data.id
        color = NSColor(calibratedRed: data.rgba[0], green: data.rgba[1],
                        blue: data.rgba[2], alpha: data.rgba[3])

        let f = data.frame
        window = KeyableWindow(
            contentRect: NSRect(x: f[0], y: f[1], width: f[2], height: f[3]),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.isFloatingPanel = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false
        // Pin to the desktop: sit just above the desktop icons but below every
        // normal application window, so it behaves like a desktop widget instead
        // of floating on top of other apps.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear

        let container = NoteBackgroundView()
        container.wantsLayer = true

        let strip = DragStrip()
        strip.translatesAutoresizingMaskIntoConstraints = false

        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.usesFontPanel = true
        textView.font = .systemFont(ofSize: 13)
        // Default text colour for new/typed text. Fixed (not the dynamic system
        // colour) so it stays legible on the coloured note background.
        textView.textColor = .black
        textView.insertionPointColor = .black
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.delegate = self
        if !data.rtf.isEmpty,
           let a = NSAttributedString(rtf: data.rtf, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(a)
        }

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.documentView = textView
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: .max, height: .max)
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true

        container.addSubview(strip)
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: container.topAnchor),
            strip.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 22),
            scroll.topAnchor.constraint(equalTo: strip.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        window.contentView = container
        window.delegate = self
        applyColor()
        window.makeKeyAndOrderFront(nil)

        let menu = NSMenu()
        let c = NSMenuItem(title: "Colour…", action: #selector(pickColor), keyEquivalent: "")
        c.target = self
        menu.addItem(c)
        menu.addItem(.separator())
        let d = NSMenuItem(title: "Delete Note", action: #selector(deleteNote), keyEquivalent: "")
        d.target = self
        menu.addItem(d)
        strip.menu = menu
    }

    @objc func pickColor() {
        // The app is an .accessory app with nonactivating panels, so it is never
        // the active app. NSColorPanel can't become key (and thus interactive)
        // unless we activate first, so activate before showing it.
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.color = color
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))

        // The colour panel has no built-in confirm button, so add a "Done"
        // accessory that closes the panel and saves immediately.
        let done = NSButton(title: "Done", target: self, action: #selector(closeColorPanel))
        done.bezelStyle = .rounded
        let holder = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 44))
        done.frame = NSRect(x: 60, y: 6, width: 100, height: 32)
        holder.addSubview(done)
        panel.accessoryView = holder

        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        color = sender.color
        NoteStore.shared.scheduleSave()
    }

    @objc private func closeColorPanel() {
        let panel = NSColorPanel.shared
        // Detach before closing: closing the panel fires its action one more time,
        // and that stray callback would revert the note to a stale colour. So
        // detach the target/action first, then commit the final colour explicitly.
        panel.setTarget(nil)
        panel.setAction(nil)
        color = panel.color
        panel.accessoryView = nil
        panel.orderOut(nil)
        NoteStore.shared.save()
    }

    @objc func deleteNote() {
        NSColorPanel.shared.setTarget(nil)
        window.orderOut(nil)
        NoteStore.shared.remove(self)
    }

    func windowDidMove(_ notification: Notification) { NoteStore.shared.scheduleSave() }
    func windowDidResize(_ notification: Notification) { NoteStore.shared.scheduleSave() }

    private func applyColor() {
        (window.contentView as? NoteBackgroundView)?.backgroundColor = color
    }

    func textDidChange(_ notification: Notification) {
        NoteStore.shared.scheduleSave()
    }

    func snapshot() -> NoteData {
        let len = textView.textStorage?.length ?? 0
        let rtf = textView.textStorage?.rtf(
            from: NSRange(location: 0, length: len),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) ?? Data()
        let r = window.frame
        let c = color.usingColorSpace(.deviceRGB) ?? .yellow
        return NoteData(id: id, rtf: rtf,
                        rgba: [c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent],
                        frame: [r.origin.x, r.origin.y, r.width, r.height])
    }
}
