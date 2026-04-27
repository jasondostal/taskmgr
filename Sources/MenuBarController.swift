import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let metricsService = MetricsService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable automatic termination — we're a menu bar app that should stay alive
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            fatalError("NSStatusItem.button is nil — cannot create menu bar item")
        }

        updateStatusTitle(cpu: 0, button: button)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 370, height: 280)
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: ContentView(metrics: metricsService, quitAction: { [weak self] in
                self?.quitApp()
            })
        )

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])

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
        guard let button = statusItem?.button, popover != nil else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func quitApp() {
        metricsService.stop()
        popover?.performClose(nil)
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        metricsService.stop()
    }
}
