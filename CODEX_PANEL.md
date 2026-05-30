Modify the macOS StockTouchBar app at /home/ubuntu/stock-watcher-touchbar-native/ to add a floating mini-panel that stays visible on screen even when other apps are active.

## What to change

### 1. Add a new file: `Sources/FloatingPanel.swift`

A small semi-transparent floating window that shows stock summary. It sits in the top-right corner of the screen, always on top of other apps.

Requirements:
- NSWindow with .floating level, always on top
- Size: about 200x30 pixels
- Position: top-right corner of screen, below menu bar
- Background: dark semi-transparent (alpha 0.85)
- Shows: "↑3 ↓2 +0.35%" with colored dots
- Shows individual stocks: "中天+2.10 航天-1.20 浪潮+0.85 ..." in a horizontal scrolling label
- Stays visible across all spaces (canJoinAllSpaces)
- Cannot become key window (doesn't steal focus)
- Ignores mouse events by default (click passes through to apps underneath)
- Has a "pin/unpin" toggle in the menu bar menu

### 2. Modify `Sources/MenuBarController.swift`

Add a "Pin Floating Panel" menu item that toggles the floating panel on/off.

### 3. Modify `Sources/AppDelegate.swift`

- Wire up the FloatingPanel lifecycle
- Pass stock data updates to the floating panel

### 4. Modify `Sources/main.swift` if needed

Keep the same entry point.

### Floating panel visual design:

```
┌──────────────────────────────────────────────┐
│ ● ↑3 ↓2 +0.35%  中天+2.10 航天-1.20 浪潮+0.85… │  ← semi-transparent dark background
└──────────────────────────────────────────────┘
```

- The ● dot color: green (mostly up), red (mostly down), grey (cached)
- Stock names: first 2 Chinese chars or full name if short
- Color per stock: green (up), red (down), grey (flat)
- If too many stocks, the text should clip or scroll

Write all files with complete, production-quality code. No placeholders.
