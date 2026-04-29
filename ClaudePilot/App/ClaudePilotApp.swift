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
    static let openTriggerWindowRequested = Notification.Name("openTriggerWindowRequested")
    static let showAboutWindowRequested = Notification.Name("showAboutWindowRequested")
}

@MainActor
final class ClaudePilotAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("claudepilot.main-window")
    private static let triggerWindowIdentifier = NSUserInterfaceItemIdentifier("claudepilot.trigger-window")
    private var mainWindow: NSWindow?
    private var triggerWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let profileStore = SharedProfileStore.instance

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化监控器（单例，启动即开始监听）
        _ = WiFiMonitor.shared
        _ = ScheduleMonitor.shared

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindowRequested),
            name: .openMainWindowRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenTriggerWindowRequested),
            name: .openTriggerWindowRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowAboutWindowRequested),
            name: .showAboutWindowRequested,
            object: nil
        )
    }

    @objc private func handleOpenMainWindowRequested() {
        showMainWindow()
    }

    @objc private func handleOpenTriggerWindowRequested() {
        showTriggerWindow()
    }

    @objc private func handleShowAboutWindowRequested() {
        showAboutWindow()
    }

    func showMainWindow() {
        if let existing = existingWindow(identifier: Self.mainWindowIdentifier) {
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
            .frame(height: 500)
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
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    func showTriggerWindow() {
        if let existing = existingWindow(identifier: Self.triggerWindowIdentifier) {
            triggerWindow = existing
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        if let window = triggerWindow {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = TriggerListView()
            .environmentObject(profileStore)
            .frame(height: 500)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.identifier = Self.triggerWindowIdentifier
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 750, height: 500))
        window.minSize = NSSize(width: 750, height: 500)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        triggerWindow = window
    }

    func showAboutWindow() {
        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: AboutView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = NSLocalizedString("about.window_title", comment: "")
        window.isReleasedWhenClosed = false
        hosting.view.layoutSubtreeIfNeeded()
        let h = hosting.view.fittingSize.height
        window.setContentSize(NSSize(width: 360, height: max(100, h)))
        window.center()
        window.delegate = self
        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === mainWindow { mainWindow = nil }
        if window === triggerWindow { triggerWindow = nil }
        if window === aboutWindow { aboutWindow = nil }
    }

    private func existingWindow(identifier: NSUserInterfaceItemIdentifier) -> NSWindow? {
        NSApplication.shared.windows.first(where: { $0.identifier == identifier })
    }
}

@main
@MainActor
struct ClaudePilotApp: App {
    @NSApplicationDelegateAdaptor(ClaudePilotAppDelegate.self) var appDelegate
    @StateObject private var profileStore = SharedProfileStore.instance
    private let languageManager = LanguageManager.shared

    init() {
        _ = languageManager
    }

    var body: some Scene {
        MenuBarExtra("ClaudePilot", systemImage: "switch.2") {
            MenuBarView()
                .environmentObject(profileStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(NSLocalizedString("about.menu_item", comment: "")) {
                    appDelegate.showAboutWindow()
                }
            }
        }
    }
}
