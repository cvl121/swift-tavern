import XCTest
@testable import SwiftTavern

/// Integration test: sends 10 messages to OpenRouter and verifies 10 responses.
/// Requires OPENROUTER_API_KEY environment variable to be set.
/// Skipped automatically if no key is provided.
final class OpenRouterAPITest: XCTestCase {
    private var apiKey: String {
        ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
    }
    private let model = "openai/gpt-4o-mini"

    private var config: APIConfiguration {
        APIConfiguration(
            apiType: .openrouter,
            apiKey: apiKey,
            baseURL: nil,
            model: model,
            generationParams: GenerationParameters(
                maxTokens: 150,
                temperature: 0.7,
                topP: 0.95,
                topK: 40,
                frequencyPenalty: 0.0,
                presencePenalty: 0.0,
                repetitionPenalty: 1.0,
                stopSequences: [],
                streamResponse: true
            )
        )
    }

    private let testMessages: [String] = [
        "Hello! What's your name?",
        "What is 2 + 2?",
        "Tell me a one-sentence joke.",
        "What color is the sky?",
        "Name three planets.",
        "What is the capital of France?",
        "Say something encouraging.",
        "What's the opposite of hot?",
        "Count from 1 to 5.",
        "Say goodbye in three words.",
    ]

    func testSend10MessagesAndReceive10Responses() async throws {
        // Skip if no API key is set
        try XCTSkipIf(apiKey.isEmpty, "OPENROUTER_API_KEY environment variable not set — skipping integration test")

        let service = OpenRouterService()
        var responses: [String] = []

        for (i, userMsg) in testMessages.enumerated() {
            let messages = [
                LLMMessage(role: .system, content: "You are a helpful, concise assistant. Keep responses under 2 sentences."),
                LLMMessage(role: .user, content: userMsg),
            ]

            var fullResponse = ""
            let stream = service.sendMessage(messages: messages, config: config)

            for try await chunk in stream {
                fullResponse += chunk
            }

            let trimmed = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[\(i + 1)/10] User: \(userMsg)")
            print("       Bot: \(trimmed.prefix(100))...")
            print()

            XCTAssertFalse(trimmed.isEmpty, "Response \(i + 1) should not be empty")
            responses.append(trimmed)

            // Small delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        XCTAssertEqual(responses.count, 10, "Should have received exactly 10 responses")

        for (i, response) in responses.enumerated() {
            XCTAssertFalse(response.isEmpty, "Response \(i + 1) should not be empty")
        }

        print("\n✅ Successfully sent 10 messages and received 10 responses via OpenRouter!")
    }
}
