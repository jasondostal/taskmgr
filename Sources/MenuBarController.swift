import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var detachedWindow: NSPanel?
    private let metricsService = MetricsService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            fatalError("NSStatusItem.button is nil — cannot create menu bar item")
        }

        updateStatusTitle(cpu: 0, button: button)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 370, height: 280)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: ContentView(metrics: metricsService, onPin: { [weak self] in
                self?.detachToWindow()
            })
        )

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        metricsService.start()
        setupStatusTitleUpdates()
    }

    private func setupStatusTitleUpdates() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem?.button else { return }
            let pct = self.metricsService.metrics.cpu.overallPercent
            DispatchQueue.main.async {
                self.updateStatusTitle(cpu: pct, button: button)
            }
        }
    }

    private func updateStatusTitle(cpu: Double, button: NSStatusBarButton) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        let text = String(format: "%.0f%%", min(cpu, 100))

        let symbolAttachment = NSTextAttachment()
        if let symbolImage = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU") {
            let config = NSImage.SymbolConfiguration(pointSize: NSFont.smallSystemFontSize, weight: .regular)
            symbolAttachment.image = symbolImage.withSymbolConfiguration(config)
            symbolAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        }

        let attrText = NSMutableAttributedString()
        attrText.append(NSAttributedString(attachment: symbolAttachment))
        attrText.append(NSAttributedString(string: "\u{2009}\(text)", attributes: [.font: font]))

        button.attributedTitle = attrText
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(button: button)
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit TaskMgr", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func detachToWindow() {
        if let existing = detachedWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        popover.performClose(nil)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 370, height: 310),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "TaskMgr"
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: ContentView(metrics: metricsService, onPin: nil)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        detachedWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSPanel, window === detachedWindow {
            detachedWindow = nil
        }
    }

    @objc private func quitApp() {
        metricsService.stop()
        popover?.performClose(nil)
        detachedWindow?.close()
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        metricsService.stop()
    }
}
