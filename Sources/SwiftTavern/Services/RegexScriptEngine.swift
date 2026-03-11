import Foundation

/// A regex replacement rule that can be applied to input or output text
struct RegexRule: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var pattern: String
    var replacement: String
    var appliesTo: RuleTarget
    var enabled: Bool
    var order: Int

    enum RuleTarget: String, Codable {
        case input, output, both
    }

    init(name: String = "", pattern: String = "", replacement: String = "",
         appliesTo: RuleTarget = .output, enabled: Bool = true, order: Int = 0) {
        self.id = UUID().uuidString
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
        self.appliesTo = appliesTo
        self.enabled = enabled
        self.order = order
    }
}

/// Applies regex replacement rules to text
enum RegexScriptEngine {
    static func applyRules(_ text: String, rules: [RegexRule], target: RegexRule.RuleTarget) -> String {
        var result = text
        let applicableRules = rules
            .filter { $0.enabled && ($0.appliesTo == target || $0.appliesTo == .both) }
            .sorted { $0.order < $1.order }

        for rule in applicableRules {
            guard !rule.pattern.isEmpty else { continue }
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: rule.replacement)
        }
        return result
    }
}
