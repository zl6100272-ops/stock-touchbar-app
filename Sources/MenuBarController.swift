import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private var snapshot = StockSnapshot(quotes: [], fetchedAt: Date(), isCached: false)
    private let onRefreshRequested: () -> Void
    private let onActivateRequested: () -> Void
    private let onPinToggle: () -> Void
    private let isPinned: () -> Bool
    private var tickerTimer: Timer?
    private var tickerIndex = 0
    private var tickerEnabled = true
    private var lastTrendColor = NSColor.systemGray

    init(onRefreshRequested: @escaping () -> Void,
         onActivateRequested: @escaping () -> Void,
         onPinToggle: @escaping () -> Void,
         isPinned: @escaping () -> Bool) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onRefreshRequested = onRefreshRequested
        self.onActivateRequested = onActivateRequested
        self.onPinToggle = onPinToggle
        self.isPinned = isPinned
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.attributedTitle = attributedStatusTitle(summary: "Loading", trendColor: .systemGray)
        }
    }

    func update(snapshot: StockSnapshot) {
        self.snapshot = snapshot
        lastTrendColor = trendColor(for: snapshot)
        updateDisplay()
    }

    private func updateDisplay() {
        guard let button = statusItem.button else { return }

        if tickerEnabled && !snapshot.quotes.isEmpty {
            startTicker()
        } else {
            stopTicker()
            button.attributedTitle = attributedStatusTitle(summary: snapshot.summary, trendColor: lastTrendColor)
        }
        let pinIndicator = isPinned() ? " 🔒" : ""
        button.toolTip = "Stock Touch Bar\(pinIndicator)"
    }

    private func startTicker() {
        guard tickerTimer == nil || !(tickerTimer?.isValid ?? false) else { return }
        tickerIndex = 0
        tickTock()
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.tickTock()
        }
        if let timer = tickerTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTicker() {
        tickerTimer?.invalidate()
        tickerTimer = nil
    }

    private func tickTock() {
        guard let button = statusItem.button else { return }
        let quotes = snapshot.quotes
        guard !quotes.isEmpty else {
            button.attributedTitle = attributedStatusTitle(summary: snapshot.summary, trendColor: lastTrendColor)
            tickerIndex = 0
            return
        }

        let totalItems = 1 + quotes.count  // summary + each stock
        if tickerIndex == 0 {
            // Show summary
            button.attributedTitle = attributedStatusTitle(summary: snapshot.summary, trendColor: lastTrendColor)
        } else {
            // Show individual stock
            let idx = tickerIndex - 1
            guard idx < quotes.count else {
                tickerIndex = 0
                tickTock()
                return
            }
            let quote = quotes[idx]
            let color: NSColor = quote.isDown ? .systemRed : (quote.isUp ? .systemGreen : .secondaryLabelColor)
            let maxNameLen = 4
            let name = quote.name.count > maxNameLen ? String(quote.name.prefix(maxNameLen)) : quote.name
            let changeStr = String(format: "%+.2f", quote.changePercent)
            let tickerText = "\(name) \(quote.price) \(changeStr)"
            let title = NSMutableAttributedString(string: "● ", attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ])
            title.append(NSAttributedString(string: tickerText, attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]))
            button.attributedTitle = title
        }
        tickerIndex = (tickerIndex + 1) % totalItems
    }

    func updateMenu() {
        if let button = statusItem.button {
            let pinIndicator = isPinned() ? " 🔒" : ""
            button.toolTip = "Stock Touch Bar\(pinIndicator)"
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        onActivateRequested()
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: snapshot.summary, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if snapshot.quotes.isEmpty {
            let empty = NSMenuItem(title: snapshot.isCached ? "No cached quotes available" : "No quotes available", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for quote in snapshot.quotes {
                let item = NSMenuItem(title: quote.menuTitle, action: nil, keyEquivalent: "")
                item.attributedTitle = attributedMenuTitle(for: quote)
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let pinItem = NSMenuItem(title: pinTitle(), action: #selector(togglePin(_:)), keyEquivalent: "s")
        pinItem.keyEquivalentModifierMask = [.command, .shift]
        pinItem.target = self
        menu.addItem(pinItem)

        let tickerItem = NSMenuItem(title: tickerTitle(), action: #selector(toggleTicker(_:)), keyEquivalent: "t")
        tickerItem.keyEquivalentModifierMask = [.command, .shift]
        tickerItem.target = self
        menu.addItem(tickerItem)

        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow(_:)), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let config = NSMenuItem(title: "Open Config Folder", action: #selector(openConfigFolder(_:)), keyEquivalent: "")
        config.target = self
        menu.addItem(config)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Stock Touch Bar", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    func updateMenu() {
        // Will be reflected on next menu open (buildMenu is called each time)
        if let button = statusItem.button, !snapshot.quotes.isEmpty {
            let pinIndicator = isPinned() ? " 🔒" : ""
            button.toolTip = "Stock Touch Bar\(pinIndicator) — Cmd+Shift+S to pin"
        }
    }

    private func pinTitle() -> String {
        isPinned() ? "☑ Unpin Touch Bar" : "☐ Pin Touch Bar"
    }

    private func tickerTitle() -> String {
        tickerEnabled ? "☑ Menu Ticker On" : "☐ Menu Ticker Off"
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        onPinToggle()
    }

    @objc private func toggleTicker(_ sender: NSMenuItem) {
        tickerEnabled.toggle()
        if !tickerEnabled {
            stopTicker()
            if let button = statusItem.button {
                button.attributedTitle = attributedStatusTitle(summary: snapshot.summary, trendColor: lastTrendColor)
            }
        } else {
            startTicker()
        }
    }

    @objc private func refreshNow(_ sender: NSMenuItem) {
        onRefreshRequested()
    }

    @objc private func openConfigFolder(_ sender: NSMenuItem) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".stock-watcher-touchbar", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func attributedStatusTitle(summary: String, trendColor: NSColor) -> NSAttributedString {
        let title = NSMutableAttributedString(string: "● ", attributes: [
            .foregroundColor: trendColor,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ])
        title.append(NSAttributedString(string: summary, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        ]))
        return title
    }

    private func attributedMenuTitle(for quote: StockQuote) -> NSAttributedString {
        let color: NSColor = quote.isDown ? .systemRed : (quote.isUp ? .systemGreen : .secondaryLabelColor)
        let title = NSMutableAttributedString(string: "● ", attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ])
        title.append(NSAttributedString(string: quote.menuTitle, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        ]))
        return title
    }

    private func trendColor(for snapshot: StockSnapshot) -> NSColor {
        if snapshot.isCached {
            return .systemGray
        }
        if snapshot.upCount > snapshot.downCount {
            return .systemGreen
        }
        if snapshot.downCount > snapshot.upCount {
            return .systemRed
        }
        return .systemGray
    }
}
