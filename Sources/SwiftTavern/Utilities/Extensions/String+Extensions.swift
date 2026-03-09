import Foundation

extension String {
    /// Sanitize a string for use as a filename
    func sanitizedFilename() -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return self.components(separatedBy: invalidChars).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Replace template variables like {{char}} and {{user}}
    func replacingTemplateVars(charName: String, userName: String) -> String {
        self.replacingOccurrences(of: "{{char}}", with: charName)
            .replacingOccurrences(of: "{{user}}", with: userName)
            .replacingOccurrences(of: "{{Char}}", with: charName)
            .replacingOccurrences(of: "{{User}}", with: userName)
    }

    /// Truncate string to a maximum length
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength - trailing.count)) + trailing
    }
}
