import Foundation

/// Estimates token counts for text and LLM message arrays
enum TokenEstimator {
    /// Estimate tokens for a single string using character-based BPE approximation.
    /// English text averages ~4 characters per token for GPT-family models.
    static func estimate(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let charCount = text.count
        let wordCount = text.split(separator: " ").count
        // Use the higher of two heuristics for safety
        return max(charCount / 4, Int(Double(wordCount) * 1.3))
    }

    /// Estimate tokens for a full LLM message array, including per-message overhead.
    /// Each message has ~4 tokens of framing overhead (role, delimiters).
    static func estimateMessages(_ messages: [LLMMessage]) -> Int {
        var total = 0
        for msg in messages {
            total += estimate(msg.content) + 4 // ~4 tokens per message overhead
        }
        total += 2 // conversation framing
        return total
    }
}
