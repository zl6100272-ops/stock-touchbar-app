# Create a Native macOS Touch Bar Stock Viewer App

Create a native macOS Swift application at /home/ubuntu/stock-watcher-touchbar-native/ that displays A-share stock quotes on the MacBook Touch Bar. No third-party dependencies (no BetterTouchTool, no BTT).

## Project Requirements

1. **Native macOS App** - Uses AppKit directly, compiled with `swiftc` or via Xcode
2. **No third-party Touch Bar tools** - Zero external dependencies
3. **Touch Bar integration** via NSTouchBar API when the app is active
4. **Menu Bar app** - Runs in menu bar (LSUIElement=true), no Dock icon
5. **Data source**: Tencent stock API `http://qt.gtimg.cn/q=sh600522,...` with GBK decoding
6. **Config**: Reads stock codes from `~/.stock-watcher-touchbar/codes.txt` (comma-separated, e.g. `sh600522,sz000977,...`)
7. **Auto-refresh**: Every 15 seconds during trading hours
8. **Color coding**: Green for up, Red for down (Chinese market convention)

## App Behavior

### Menu Bar
- Shows a compact summary: e.g. "↑3 ↓2 +0.35%"
- Click opens a popover/menu with individual stock list (name, price, change%)
- Green/red dot indicator in menu bar icon

### Touch Bar (when app is active)
- Scrolling set of NSTouchBarItem buttons, one per stock
- Each button shows: stock name (2 chars) + change% (e.g., "中天+2.10")
- Background color: green for up, red for down
- First item is a summary: "↑3 ↓2" or "Avg +0.35%"
- Touch Bar updates every 15 seconds

### Stock Data Format (from Tencent API)
- URL: `http://qt.gtimg.cn/q=sh600522,sz000977,...`
- GBK encoded, need to decode to UTF-8
- Fields separated by `~`
- Field 1 (index 1): Name
- Field 2 (index 2): Code
- Field 3 (index 3): Current Price
- Field 31 (index 31): Price Change (涨跌额)
- Field 32 (index 32): Change % (涨跌幅, e.g. "+2.10%")

### Fallback Cache
- If API fails, read from `~/.stock-watcher-touchbar/cache.txt` (output of fetch_stocks.sh)
- Show last known data with a "cached" indicator

## Files to Create

Create these files in /home/ubuntu/stock-watcher-touchbar-native/:

1. `Sources/main.swift` - Entry point
2. `Sources/AppDelegate.swift` - App lifecycle, menu bar, Touch Bar
3. `Sources/StockData.swift` - Data model and API client  
4. `Sources/TouchBarController.swift` - NSTouchBar delegate and item provider
5. `Sources/MenuBarController.swift` - NSStatusItem and popover
6. `Info.plist` - Bundle info with LSUIElement=true
7. `build.sh` - Build script that produces StockTouchBar.app
8. `README.md` - Usage instructions

## Important Technical Details

### GBK Decoding in Swift
```swift
let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
let gbkEncoding = String.Encoding(rawValue: encoding)
let decodedString = String(data: rawData, encoding: gbkEncoding)
```

### NSTouchBar Setup
- Use `NSTouchBarDelegate` with `makeItemForIdentifier`
- Each stock is an `NSCustomTouchBarItem` with an `NSButton`
- Button title: stock short name + change%
- Button bezelColor: .systemGreen (up) or .systemRed (down)
- Summary item: fixed width showing up/down count

### Menu Bar Setup
- Create NSStatusItem with variable length
- Set button title to summary string
- Attach NSMenu or NSPopover

### Bundle Structure
```
StockTouchBar.app/
  Contents/
    Info.plist
    MacOS/
      StockTouchBar    (compiled binary)
```

## Build Script (build.sh)
The build script should:
1. Create .app bundle directory structure
2. Copy Info.plist
3. Compile all Swift files with swiftc: `swiftc -o StockTouchBar.app/Contents/MacOS/StockTouchBar Sources/*.swift -framework AppKit -framework Foundation`
4. Print success message

## Default Stock Codes (if no codes.txt exists)
sh600522,sh600487,sh600378,sh600879,sz000977,sh603667,sz002463,sz002156,sh603690,sh562500

Write all files with complete, production-quality code. DO NOT leave placeholder comments or TODOs. Every function must be fully implemented.
