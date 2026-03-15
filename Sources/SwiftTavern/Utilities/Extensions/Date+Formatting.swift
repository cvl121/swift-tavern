import Foundation

extension Date {
    /// Date string for chat metadata
    var chatDateString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }

    /// Generate a chat filename-safe date string
    var chatFileDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: self)
    }

    /// Display-friendly static timestamp
    var relativeDisplayString: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
        }
        return formatter.string(from: self)
    }
}

extension String {
    /// Parse a chat metadata date string to Date
    var chatDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: self)
    }
}
