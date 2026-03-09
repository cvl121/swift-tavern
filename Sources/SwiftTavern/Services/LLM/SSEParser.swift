import Foundation

/// Parser for Server-Sent Events (SSE) streams
struct SSEParser {
    /// Parse a single line from an SSE stream
    /// Returns the event type and data, or nil if the line is empty/comment
    static func parseLine(_ line: String) -> SSEEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty || trimmed.hasPrefix(":") {
            return nil
        }

        if trimmed.hasPrefix("data: ") {
            let data = String(trimmed.dropFirst(6))
            if data == "[DONE]" {
                return SSEEvent(type: .done, data: "")
            }
            return SSEEvent(type: .data, data: data)
        }

        if trimmed.hasPrefix("event: ") {
            let eventName = String(trimmed.dropFirst(7))
            return SSEEvent(type: .event(eventName), data: "")
        }

        return nil
    }

    /// Parse a complete SSE message (may span multiple lines)
    static func parseBlock(_ block: String) -> (eventName: String?, data: String?) {
        var eventName: String?
        var dataLines: [String] = []

        for line in block.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("event: ") {
                eventName = String(trimmed.dropFirst(7))
            } else if trimmed.hasPrefix("data: ") {
                dataLines.append(String(trimmed.dropFirst(6)))
            }
        }

        let data = dataLines.isEmpty ? nil : dataLines.joined(separator: "\n")
        return (eventName: eventName, data: data)
    }
}

struct SSEEvent {
    let type: SSEEventType
    let data: String
}

enum SSEEventType: Equatable {
    case data
    case done
    case event(String)
}
