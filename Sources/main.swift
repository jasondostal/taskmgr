import AppKit

NSApplication.shared.setActivationPolicy(.accessory)

// NSApplication.delegate is weak — hold strong ref in a global
private var appDelegate: MenuBarController?

let delegate = MenuBarController()
appDelegate = delegate
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
