import AppKit
import SwiftUI

// MARK: - App

@main
struct NoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings {} }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Notes"

        let menu = NSMenu()

        let newItem = NSMenuItem(title: "New Note",
                                 action: #selector(NoteStore.newNote),
                                 keyEquivalent: "n")
        newItem.target = NoteStore.shared
        menu.addItem(newItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu

        NoteStore.shared.load()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NoteStore.shared.save()
    }
}
