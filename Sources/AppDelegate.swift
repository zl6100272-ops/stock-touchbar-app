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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createTouchBarHost()

        menuBarController = MenuBarController(
            onRefreshRequested: { [weak self] in self?.refreshQuotes(force: true) },
            onActivateRequested: { [weak self] in self?.activateForTouchBar() },
            onPinToggle: { /* no-op, Touch Bar can't persist in macOS */ },
            isPinned: { false }
        )

        refreshQuotes(force: true)
        startRefreshTimer()
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
        hostWindow?.makeKeyAndOrderFront(nil)
        hostViewController?.view.window?.makeFirstResponder(hostViewController?.view)
        NSApp.activate(ignoringOtherApps: true)
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
