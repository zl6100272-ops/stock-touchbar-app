import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let dataClient = StockDataClient()
    private let touchBarController = TouchBarController()
    private var menuBarController: MenuBarController?
    private var hostWindow: NSWindow?
    private var hostViewController: TouchBarHostViewController?
    private var refreshTimer: Timer?
    private var lastSnapshot = StockSnapshot(quotes: [], fetchedAt: Date(), isCached: false)
    private var isRefreshing = false
    private var isTouchBarPinned = false
    private var pinCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createTouchBarHost()

        menuBarController = MenuBarController(
            onRefreshRequested: { [weak self] in self?.refreshQuotes(force: true) },
            onActivateRequested: { [weak self] in self?.activateForTouchBar() },
            onPinToggle: { [weak self] in self?.toggleTouchBarPin() },
            isPinned: { [weak self] in self?.isTouchBarPinned ?? false }
        )

        refreshQuotes(force: true)
        startRefreshTimer()
        registerGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func createTouchBarHost() {
        let hostViewController = TouchBarHostViewController(touchBarController: touchBarController)
        let window = TouchBarHostPanel(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostViewController
        window.alphaValue = 0.01
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.orderFrontRegardless()
        window.isReleasedWhenClosed = false
        self.hostWindow = window
        self.hostViewController = hostViewController
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshQuotes(force: false)
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshQuotes(force: Bool) {
        guard force || StockDataClient.isTradingTime() else {
            return
        }

        guard !isRefreshing else { return }
        isRefreshing = true

        dataClient.fetchQuotes { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                self.apply(snapshot: snapshot)
            }
        }
    }

    private func apply(snapshot: StockSnapshot) {
        lastSnapshot = snapshot
        menuBarController?.update(snapshot: snapshot)
        touchBarController.update(snapshot: snapshot)
        hostViewController?.refreshTouchBar()
    }

    private func activateForTouchBar() {
        if isTouchBarPinned {
            unpinTouchBar()
        }
        hostWindow?.makeKeyAndOrderFront(nil)
        hostViewController?.view.window?.makeFirstResponder(hostViewController?.view)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleTouchBarPin() {
        if isTouchBarPinned {
            unpinTouchBar()
        } else {
            pinTouchBar()
        }
    }

    private func pinTouchBar() {
        isTouchBarPinned = true
        hostWindow?.makeKeyAndOrderFront(nil)
        hostWindow?.level = .statusBar
        // Keep the panel as key window using a timer
        pinCheckTimer?.invalidate()
        pinCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isTouchBarPinned else { return }
            // Ensure our invisible panel stays key without stealing focus
            if let window = self.hostWindow, !window.isKeyWindow {
                window.orderFrontRegardless()
                // Use makeKey without activating the app (possible with nonactivatingPanel)
                // We just need it to be in the window list; the NSTouchBar system
                // will pick it up when the panel is ordered front
            }
        }
        if let timer = pinCheckTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        menuBarController?.updateMenu()
    }

    private func unpinTouchBar() {
        isTouchBarPinned = false
        pinCheckTimer?.invalidate()
        pinCheckTimer = nil
        hostWindow?.resignKey()
        menuBarController?.updateMenu()
    }

    private func registerGlobalHotkey() {
        // Register Cmd+Shift+S as global shortcut to toggle pin
        let eventMask: NSEvent.EventTypeMask = [.keyDown]
        NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            guard let self = self else { return event }
            if event.modifierFlags.contains([.command, .shift]),
               event.charactersIgnoringModifiers?.lowercased() == "s" {
                self.toggleTouchBarPin()
                return nil // consume the event
            }
            return event
        }
    }
}

final class TouchBarHostPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
