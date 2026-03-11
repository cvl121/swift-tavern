import Foundation

/// Lookup table for known model context window sizes
enum ModelContextLimits {
    /// Returns the context window size (in tokens) for a known model, or nil if unknown
    static func contextWindow(for model: String) -> Int? {
        let lower = model.lowercased()

        // OpenAI
        if lower.contains("gpt-4o") || lower.contains("gpt-4.1") || lower.contains("chatgpt-4o") { return 128_000 }
        if lower.contains("o1") || lower.contains("o3") || lower.contains("o4") { return 128_000 }
        if lower.contains("gpt-4-turbo") || lower.contains("gpt-4-0125") || lower.contains("gpt-4-1106") { return 128_000 }
        if lower.contains("gpt-4") { return 8_192 }
        if lower.contains("gpt-3.5-turbo") { return 16_385 }

        // Anthropic Claude
        if lower.contains("claude-opus-4") || lower.contains("claude-sonnet-4") { return 200_000 }
        if lower.contains("claude-3-5") || lower.contains("claude-3.5") { return 200_000 }
        if lower.contains("claude-3") { return 200_000 }
        if lower.contains("claude-haiku-4") { return 200_000 }
        if lower.contains("claude") { return 200_000 }

        // Google Gemini
        if lower.contains("gemini-2.5") { return 1_000_000 }
        if lower.contains("gemini-2.0") { return 1_000_000 }
        if lower.contains("gemini-1.5-pro") { return 2_000_000 }
        if lower.contains("gemini-1.5-flash") { return 1_000_000 }
        if lower.contains("gemini") { return 1_000_000 }

        // Meta Llama
        if lower.contains("llama-4") { return 1_000_000 }
        if lower.contains("llama-3.3") || lower.contains("llama3.3") { return 128_000 }
        if lower.contains("llama-3.1") || lower.contains("llama3.1") { return 128_000 }
        if lower.contains("llama-3.2") || lower.contains("llama3.2") { return 128_000 }
        if lower.contains("llama3") || lower.contains("llama-3") { return 8_192 }

        // Mistral
        if lower.contains("mistral-large") { return 128_000 }
        if lower.contains("mistral-small") { return 128_000 }
        if lower.contains("mixtral") { return 32_768 }
        if lower.contains("mistral-nemo") { return 128_000 }
        if lower.contains("mistral") { return 32_768 }

        // Qwen
        if lower.contains("qwen") { return 32_768 }
        if lower.contains("qwq") { return 32_768 }

        // DeepSeek
        if lower.contains("deepseek-r1") { return 64_000 }
        if lower.contains("deepseek") { return 64_000 }

        // NovelAI
        if lower.contains("kayra") { return 8_192 }
        if lower.contains("clio") { return 8_192 }
        if lower.contains("erato") { return 8_192 }

        // Cohere
        if lower.contains("command-r") { return 128_000 }

        // xAI
        if lower.contains("grok") { return 131_072 }

        // Other Ollama models
        if lower.contains("phi4") || lower.contains("phi3") { return 16_384 }
        if lower.contains("gemma") { return 8_192 }
        if lower.contains("codellama") { return 16_384 }

        return nil
    }

    /// Format a token count for display (e.g., "128k", "1M")
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let m = Double(count) / 1_000_000
            return m.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(m))M" : String(format: "%.1fM", m)
        } else if count >= 1_000 {
            let k = Double(count) / 1_000
            return k.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(k))k" : String(format: "%.1fk", k)
        }
        return "\(count)"
    }
}
