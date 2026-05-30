import AppKit

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private enum Constants {
        static let summaryIdentifier = NSTouchBarItem.Identifier("com.stocktouchbar.summary")
        static let stockPrefix = "com.stocktouchbar.stock."
    }

    private var snapshot = StockSnapshot(quotes: [], fetchedAt: Date(), isCached: false)

    func update(snapshot: StockSnapshot) {
        self.snapshot = snapshot
    }

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.stocktouchbar.main")
        touchBar.defaultItemIdentifiers = itemIdentifiers()
        touchBar.customizationAllowedItemIdentifiers = itemIdentifiers()
        touchBar.principalItemIdentifier = Constants.summaryIdentifier
        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == Constants.summaryIdentifier {
            return makeSummaryItem(identifier: identifier)
        }

        guard let index = stockIndex(from: identifier), snapshot.quotes.indices.contains(index) else {
            return nil
        }

        return makeStockItem(identifier: identifier, quote: snapshot.quotes[index])
    }

    private func itemIdentifiers() -> [NSTouchBarItem.Identifier] {
        [Constants.summaryIdentifier] + snapshot.quotes.indices.map { NSTouchBarItem.Identifier("\(Constants.stockPrefix)\($0)") }
    }

    private func stockIndex(from identifier: NSTouchBarItem.Identifier) -> Int? {
        let raw = identifier.rawValue
        guard raw.hasPrefix(Constants.stockPrefix) else { return nil }
        return Int(raw.dropFirst(Constants.stockPrefix.count))
    }

    private func makeSummaryItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(title: snapshot.touchBarSummary, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.isEnabled = false
        button.widthAnchor.constraint(equalToConstant: 92).isActive = true
        if snapshot.isCached {
            button.contentTintColor = .secondaryLabelColor
        }
        item.view = button
        return item
    }

    private func makeStockItem(identifier: NSTouchBarItem.Identifier, quote: StockQuote) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(title: quote.touchBarTitle, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.isEnabled = false
        button.contentTintColor = .white
        button.bezelColor = quote.isDown ? .systemRed : (quote.isUp ? .systemGreen : .systemGray)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
        item.view = button
        return item
    }
}

final class TouchBarHostViewController: NSViewController {
    private let touchBarController: TouchBarController

    init(touchBarController: TouchBarController) {
        self.touchBarController = touchBarController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        view = TouchBarHostView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override func makeTouchBar() -> NSTouchBar? {
        touchBarController.makeTouchBar()
    }

    func refreshTouchBar() {
        touchBar = touchBarController.makeTouchBar()
    }
}

final class TouchBarHostView: NSView {
    override var acceptsFirstResponder: Bool {
        true
    }
}
