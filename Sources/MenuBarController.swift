import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private var snapshot = StockSnapshot(quotes: [], fetchedAt: Date(), isCached: false)
    private let onRefreshRequested: () -> Void
    private let onActivateRequested: () -> Void
    private let onPinToggle: () -> Void
    private let isPinned: () -> Bool

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
        if let button = statusItem.button {
            button.attributedTitle = attributedStatusTitle(summary: snapshot.summary, trendColor: trendColor(for: snapshot))
            button.toolTip = snapshot.isCached ? "Stock Touch Bar - cached quotes" : "Stock Touch Bar"
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

    @objc private func togglePin(_ sender: NSMenuItem) {
        onPinToggle()
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
