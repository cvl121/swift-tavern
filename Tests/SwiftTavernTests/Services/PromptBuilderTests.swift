import XCTest
@testable import SwiftTavern

final class PromptBuilderTests: XCTestCase {
    func testBuildBasicMessages() {
        let character = CharacterData(
            name: "Alice",
            description: "A friendly AI",
            personality: "Kind and helpful",
            scenario: "Chatting in a cafe",
            firstMes: "",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "You are {{char}}, talking to {{user}}.",
            postHistoryInstructions: ""
        )

        let chatHistory = [
            ChatMessage(name: "User", isUser: true, mes: "Hello Alice!"),
            ChatMessage(name: "Alice", isUser: false, mes: "Hi there!"),
        ]

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: chatHistory,
            userName: "User"
        )

        // Should have: system prompt + 2 chat messages
        XCTAssertGreaterThanOrEqual(messages.count, 3)

        // First message should be system
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertTrue(messages[0].content.contains("You are Alice, talking to User."))

        // Chat history
        let userMsg = messages.first { $0.role == .user }
        XCTAssertEqual(userMsg?.content, "Hello Alice!")

        let assistantMsg = messages.first { $0.role == .assistant }
        XCTAssertEqual(assistantMsg?.content, "Hi there!")
    }

    func testTemplateVariableReplacement() {
        let character = CharacterData(
            name: "Bob",
            description: "{{char}} is a robot. {{user}} is human.",
            personality: "",
            scenario: "",
            firstMes: "",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "Play as {{char}}.",
            postHistoryInstructions: ""
        )

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: [],
            userName: "Alice"
        )

        let systemContent = messages[0].content
        XCTAssertTrue(systemContent.contains("Play as Bob."))
        XCTAssertTrue(systemContent.contains("Bob is a robot. Alice is human."))
        XCTAssertFalse(systemContent.contains("{{char}}"))
        XCTAssertFalse(systemContent.contains("{{user}}"))
    }

    func testExampleMessagesParsing() {
        let example = """
        <START>
        {{user}}: What do you like?
        {{char}}: I like programming and tea!
        {{user}}: Tell me more
        {{char}}: Well, I also enjoy reading books.
        """

        let messages = PromptBuilder.parseExampleMessages(
            example,
            characterName: "Bot",
            userName: "User"
        )

        XCTAssertEqual(messages.count, 4)
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[0].content, "What do you like?")
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[1].content, "I like programming and tea!")
        XCTAssertEqual(messages[2].role, .user)
        XCTAssertEqual(messages[3].role, .assistant)
    }

    func testWorldInfoConstantEntries() {
        let character = CharacterData(name: "Test", description: "", personality: "", scenario: "", firstMes: "", mesExample: "", creatorNotes: "", systemPrompt: "System.", postHistoryInstructions: "")

        let worldEntries = [
            WorldInfoEntry(uid: 0, keys: ["keyword"], content: "This is world info", enabled: true, constant: true),
        ]

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: [],
            userName: "User",
            worldInfoEntries: worldEntries
        )

        let systemContent = messages[0].content
        XCTAssertTrue(systemContent.contains("This is world info"))
    }

    func testWorldInfoKeywordTriggered() {
        let character = CharacterData(name: "Test", description: "", personality: "", scenario: "", firstMes: "", mesExample: "", creatorNotes: "", systemPrompt: "System.", postHistoryInstructions: "")

        let worldEntries = [
            WorldInfoEntry(uid: 0, keys: ["dragon"], content: "Dragons are powerful creatures", enabled: true),
            WorldInfoEntry(uid: 1, keys: ["unicorn"], content: "Unicorns are magical", enabled: true),
        ]

        let chatHistory = [
            ChatMessage(name: "User", isUser: true, mes: "Tell me about the dragon"),
        ]

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: chatHistory,
            userName: "User",
            worldInfoEntries: worldEntries
        )

        let systemContent = messages[0].content
        XCTAssertTrue(systemContent.contains("Dragons are powerful creatures"))
        XCTAssertFalse(systemContent.contains("Unicorns are magical"))
    }

    func testPostHistoryInstructions() {
        let character = CharacterData(
            name: "Test",
            description: "",
            personality: "",
            scenario: "",
            firstMes: "",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "System.",
            postHistoryInstructions: "Remember to stay in character."
        )

        let chatHistory = [
            ChatMessage(name: "User", isUser: true, mes: "Hello"),
        ]

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: chatHistory,
            userName: "User"
        )

        // Post-history instructions should be the last system message
        let lastMessage = messages.last!
        XCTAssertEqual(lastMessage.role, .system)
        XCTAssertEqual(lastMessage.content, "Remember to stay in character.")
    }

    func testPersonaDescription() {
        let character = CharacterData(name: "Test", description: "", personality: "", scenario: "", firstMes: "", mesExample: "", creatorNotes: "", systemPrompt: "System.", postHistoryInstructions: "")

        let persona = Persona(name: "Hero", description: "A brave warrior from the north")

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: [],
            userName: "Hero",
            persona: persona
        )

        let systemContent = messages[0].content
        XCTAssertTrue(systemContent.contains("Hero's description: A brave warrior from the north"))
    }
}
