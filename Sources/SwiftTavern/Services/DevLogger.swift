import Foundation

/// Thread-safe developer log for tracking API requests and responses
@Observable
final class DevLogger {
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: LogType
        let message: String

        enum LogType: String {
            case request = "REQ"
            case response = "RES"
            case error = "ERR"
            case info = "INFO"
        }

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }

    var entries: [LogEntry] = []
    private let maxEntries = 500

    func log(_ type: LogEntry.LogType, _ message: String) {
        let entry = LogEntry(timestamp: Date(), type: type, message: message)
        if Thread.isMainThread {
            append(entry)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.append(entry)
            }
        }
    }

    private func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
