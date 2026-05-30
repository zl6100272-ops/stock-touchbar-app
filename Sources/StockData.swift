import Foundation
import CoreFoundation

struct StockQuote: Equatable {
    let queryCode: String
    let code: String
    let name: String
    let price: Double
    let priceChange: Double
    let changePercent: Double
    let isCached: Bool

    var isUp: Bool {
        changePercent > 0
    }

    var isDown: Bool {
        changePercent < 0
    }

    var shortName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 2 {
            return trimmed
        }
        return String(trimmed.prefix(2))
    }

    var touchBarTitle: String {
        "\(shortName)\(StockQuote.percentFormatter.string(from: NSNumber(value: changePercent)) ?? String(format: "%+.2f", changePercent))"
    }

    var menuTitle: String {
        let percent = StockQuote.percentWithSymbolFormatter.string(from: NSNumber(value: changePercent)) ?? String(format: "%+.2f%%", changePercent)
        return "\(name)  \(StockQuote.priceFormatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price))  \(percent)"
    }

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "-"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let percentWithSymbolFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "-"
        formatter.positiveSuffix = "%"
        formatter.negativeSuffix = "%"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct StockSnapshot {
    let quotes: [StockQuote]
    let fetchedAt: Date
    let isCached: Bool

    var upCount: Int {
        quotes.filter(\.isUp).count
    }

    var downCount: Int {
        quotes.filter(\.isDown).count
    }

    var averageChangePercent: Double {
        guard !quotes.isEmpty else { return 0 }
        return quotes.reduce(0) { $0 + $1.changePercent } / Double(quotes.count)
    }

    var summary: String {
        if quotes.isEmpty {
            return "No Quotes"
        }

        let average = String(format: "%+.2f%%", averageChangePercent)
        let cached = isCached ? " cached" : ""
        return "↑\(upCount) ↓\(downCount) \(average)\(cached)"
    }

    var touchBarSummary: String {
        if quotes.isEmpty {
            return isCached ? "Cached" : "No Data"
        }
        return "↑\(upCount) ↓\(downCount)"
    }
}

final class StockDataClient {
    static let defaultCodes = [
        "sh600522",
        "sh600487",
        "sh600378",
        "sh600879",
        "sz000977",
        "sh603667",
        "sz002463",
        "sz002156",
        "sh603690",
        "sh562500"
    ]

    private let session: URLSession
    private let fileManager: FileManager
    private let configDirectory: URL
    private let codesFile: URL
    private let cacheFile: URL

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
        let home = fileManager.homeDirectoryForCurrentUser
        self.configDirectory = home.appendingPathComponent(".stock-watcher-touchbar", isDirectory: true)
        self.codesFile = configDirectory.appendingPathComponent("codes.txt")
        self.cacheFile = configDirectory.appendingPathComponent("cache.txt")
    }

    func fetchQuotes(completion: @escaping (StockSnapshot) -> Void) {
        let codes = loadCodes()
        guard !codes.isEmpty else {
            completion(StockSnapshot(quotes: [], fetchedAt: Date(), isCached: false))
            return
        }

        guard let url = URL(string: "http://qt.gtimg.cn/q=\(codes.joined(separator: ","))") else {
            completion(loadCachedSnapshot(for: codes))
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            if let data, error == nil, let body = Self.decodeTencentResponse(data), !body.isEmpty {
                let quotes = Self.parseTencentResponse(body, requestedCodes: codes, cached: false)
                if !quotes.isEmpty {
                    self.writeCache(body)
                    completion(StockSnapshot(quotes: quotes, fetchedAt: Date(), isCached: false))
                    return
                }
            }

            completion(self.loadCachedSnapshot(for: codes))
        }
        task.resume()
    }

    func loadCodes() -> [String] {
        ensureConfigDirectoryExists()

        guard let content = try? String(contentsOf: codesFile, encoding: .utf8) else {
            return Self.defaultCodes
        }

        let separated = content.components(separatedBy: CharacterSet(charactersIn: ",\n\r\t "))
        let codes = separated
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return codes.isEmpty ? Self.defaultCodes : codes
    }

    private func loadCachedSnapshot(for codes: [String]) -> StockSnapshot {
        guard let cachedBody = try? String(contentsOf: cacheFile, encoding: .utf8) else {
            return StockSnapshot(quotes: [], fetchedAt: Date(), isCached: true)
        }

        let quotes = Self.parseTencentResponse(cachedBody, requestedCodes: codes, cached: true)
        return StockSnapshot(quotes: quotes, fetchedAt: Date(), isCached: true)
    }

    private func ensureConfigDirectoryExists() {
        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
    }

    private func writeCache(_ body: String) {
        ensureConfigDirectoryExists()
        try? body.write(to: cacheFile, atomically: true, encoding: .utf8)
    }

    private static func decodeTencentResponse(_ rawData: Data) -> String? {
        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        let gbkEncoding = String.Encoding(rawValue: encoding)
        return String(data: rawData, encoding: gbkEncoding)
    }

    static func parseTencentResponse(_ response: String, requestedCodes: [String], cached: Bool) -> [StockQuote] {
        let records = response
            .components(separatedBy: ";\n")
            .flatMap { $0.components(separatedBy: ";") }

        let parsed = records.compactMap { record -> StockQuote? in
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return parseTencentRecord(trimmed, cached: cached)
        }

        if requestedCodes.isEmpty {
            return parsed
        }

        let byQueryCode = Dictionary(uniqueKeysWithValues: parsed.map { ($0.queryCode.lowercased(), $0) })
        return requestedCodes.compactMap { byQueryCode[$0.lowercased()] }
    }

    private static func parseTencentRecord(_ record: String, cached: Bool) -> StockQuote? {
        guard let equalsRange = record.range(of: "=") else { return nil }

        let variable = String(record[..<equalsRange.lowerBound])
        let queryCode = variable
            .replacingOccurrences(of: "v_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let payload = record[equalsRange.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r\t"))
        let fields = payload.components(separatedBy: "~")

        guard fields.count > 32 else { return nil }

        let name = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let code = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let price = Double(fields[3]) ?? 0
        let priceChange = Double(fields[31].replacingOccurrences(of: "+", with: "")) ?? 0
        let changePercent = Double(fields[32].replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "+", with: "")) ?? 0

        guard !name.isEmpty else { return nil }

        return StockQuote(
            queryCode: queryCode,
            code: code,
            name: name,
            price: price,
            priceChange: priceChange,
            changePercent: changePercent,
            isCached: cached
        )
    }

    static func isTradingTime(date: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current

        let weekday = calendar.component(.weekday, from: date)
        guard weekday >= 2 && weekday <= 6 else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutes = hour * 60 + minute

        let morningOpen = 9 * 60 + 30
        let morningClose = 11 * 60 + 30
        let afternoonOpen = 13 * 60
        let afternoonClose = 15 * 60

        return (minutes >= morningOpen && minutes <= morningClose) || (minutes >= afternoonOpen && minutes <= afternoonClose)
    }
}
