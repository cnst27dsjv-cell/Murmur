import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var widgetController: WidgetWindowController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var hasStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        NSLog("Murmur did finish launching")
        let state = store.load()
        widgetController = WidgetWindowController(state: state, store: store)
        widgetController?.showWindow(nil)
        setupMainMenu()
        setupStatusItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showSettings()
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Murmur")
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Murmur", action: #selector(quit), keyEquivalent: "q"))

        for item in appMenu.items {
            item.target = self
        }

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Murmur"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Cover", action: #selector(toggleCover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Murmur", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        item.menu = menu
        statusItem = item
    }

    @objc private func showWidget() {
        widgetController?.showWindow(nil)
    }

    @objc private func toggleCover() {
        widgetController?.toggleBlurred()
    }

    @objc func showSettings() {
        guard let widgetController else { return }
        widgetController.showInlineSettings()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
