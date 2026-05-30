# Stock Touch Bar

Native macOS menu bar app that displays Tencent A-share quotes in the MacBook Touch Bar while the app is active.

## Build

```bash
cd /home/ubuntu/stock-watcher-touchbar-native
chmod +x build.sh
./build.sh
```

The build creates:

```text
StockTouchBar.app/
  Contents/
    Info.plist
    MacOS/
      StockTouchBar
```

Run it with:

```bash
open StockTouchBar.app
```

## Configuration

Stock codes are read from:

```text
~/.stock-watcher-touchbar/codes.txt
```

Use comma-separated Tencent market codes:

```text
sh600522,sz000977,sh603667
```

If the file is missing or empty, the app uses:

```text
sh600522,sh600487,sh600378,sh600879,sz000977,sh603667,sz002463,sz002156,sh603690,sh562500
```

## Behavior

- Runs as an `LSUIElement` menu bar app with no Dock icon.
- Fetches `http://qt.gtimg.cn/q=...` and decodes Tencent GB18030/GBK response data.
- Refreshes every 15 seconds during A-share trading sessions: 09:30-11:30 and 13:00-15:00 China time, Monday through Friday.
- The menu bar summary shows up/down counts and average change percentage.
- The menu lists each configured stock with name, price, and change percentage.
- The Touch Bar shows a summary item followed by one button per stock.
- Green means up and red means down, following Chinese market convention.
- If the API fetch fails, the app reads last known Tencent-format data from:

```text
~/.stock-watcher-touchbar/cache.txt
```

The app writes successful API responses to the same cache file.

## Notes

Touch Bar content is visible when the app is active. Click the menu bar item to activate the app and show the current Touch Bar items.
