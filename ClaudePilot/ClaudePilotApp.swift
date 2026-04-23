//
//  ClaudePilotApp.swift
//  ClaudePilot
//
//  Created by 刘卓明 on 2026/4/23.
//

import SwiftUI
import AppKit

@MainActor
enum SharedProfileStore {
    static let instance = ProfileStore()
}

extension Notification.Name {
    static let openMainWindowRequested = Notification.Name("openMainWindowRequested")
}

@MainActor
final class ClaudePilotAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("claudepilot.main-window")
    private var mainWindow: NSWindow?
    private let profileStore = SharedProfileStore.instance

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindowRequested),
            name: .openMainWindowRequested,
            object: nil
        )
    }

    @objc private func handleOpenMainWindowRequested() {
        showMainWindow()
    }

    func showMainWindow() {
        if let existing = existingMainWindow() {
            mainWindow = existing
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = ContentView()
            .environmentObject(profileStore)
            .frame(width: 750, height: 500)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.identifier = Self.mainWindowIdentifier
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 750, height: 500))
        window.minSize = NSSize(width: 750, height: 500)
        window.maxSize = NSSize(width: 750, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else {
            return
        }
        mainWindow = nil
    }

    private func existingMainWindow() -> NSWindow? {
        NSApplication.shared.windows.first(where: { $0.identifier == Self.mainWindowIdentifier })
    }
}

@main
@MainActor
struct ClaudePilotApp: App {
    @NSApplicationDelegateAdaptor(ClaudePilotAppDelegate.self) var appDelegate
    @StateObject private var profileStore = SharedProfileStore.instance

    var body: some Scene {
        MenuBarExtra("ClaudePilot", systemImage: "switch.2") {
            MenuBarView()
                .environmentObject(profileStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
    }
}
