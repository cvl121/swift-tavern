import Foundation

/// Thread-safe service for managing chat history files (JSONL format)
final class ChatStorageService: @unchecked Sendable {
    private let directoryManager: DataDirectoryManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let ioQueue = DispatchQueue(label: "com.swifttavern.chatstorage", qos: .userInitiated)

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
    }

    /// Get the chat directory for a specific character
    private func chatDirectory(for characterName: String) -> URL {
        directoryManager.chatsDirectory.appendingPathComponent(
            characterName.sanitizedFilename(), isDirectory: true
        )
    }

    /// Ensure the chat directory exists for a character
    private func ensureChatDirectory(for characterName: String) throws -> URL {
        let dir = chatDirectory(for: characterName)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Create a new chat session
    func createChat(characterName: String, userName: String, firstMessage: String?) throws -> ChatSession {
        let chatDir = try ensureChatDirectory(for: characterName)
        let chatId = "\(Date().chatFileDateString)-\(UUID().uuidString.prefix(8))"
        let filename = "\(characterName.sanitizedFilename()) - \(chatId).jsonl"
        let fileURL = chatDir.appendingPathComponent(filename)

        let metadata = ChatMetadata(
            userName: userName,
            characterName: characterName,
            chatMetadata: ChatMetadataInfo(),
            createDate: Date().sillyTavernDateString
        )

        var messages: [ChatMessage] = []
        var lines = [try encodeLine(metadata)]

        if let firstMes = firstMessage, !firstMes.isEmpty {
            let message = ChatMessage(
                name: characterName,
                isUser: false,
                mes: firstMes
            )
            messages.append(message)
            lines.append(try encodeLine(message))
        }

        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return ChatSession(
            id: chatId,
            filename: filename,
            metadata: metadata,
            messages: messages
        )
    }

    /// Load a chat session from a file
    func loadChat(characterName: String, filename: String) throws -> ChatSession {
        let chatDir = chatDirectory(for: characterName)
        let fileURL = chatDir.appendingPathComponent(filename)
        return try loadChat(from: fileURL)
    }

    /// Load a chat session from a URL
    func loadChat(from fileURL: URL) throws -> ChatSession {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        guard let firstLine = lines.first,
              let firstLineData = firstLine.data(using: .utf8) else {
            throw ChatStorageError.invalidFormat
        }

        let metadata = try decoder.decode(ChatMetadata.self, from: firstLineData)

        var messages: [ChatMessage] = []
        for line in lines.dropFirst() {
            if let lineData = line.data(using: .utf8),
               let message = try? decoder.decode(ChatMessage.self, from: lineData) {
                messages.append(message)
            }
        }

        let chatId = fileURL.deletingPathExtension().lastPathComponent
        return ChatSession(
            id: chatId,
            filename: fileURL.lastPathComponent,
            metadata: metadata,
            messages: messages
        )
    }

    /// Thread-safe append a message to an existing chat
    func appendMessage(_ message: ChatMessage, characterName: String, filename: String) throws {
        try ioQueue.sync {
            let chatDir = chatDirectory(for: characterName)
            let fileURL = chatDir.appendingPathComponent(filename)

            let line = try encodeLine(message) + "\n"
            guard let data = line.data(using: .utf8) else {
                throw ChatStorageError.encodingFailed
            }

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        }
    }

    /// Async version of appendMessage that runs file I/O off the main thread
    func appendMessageAsync(_ message: ChatMessage, characterName: String, filename: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ioQueue.async { [self] in
                do {
                    let chatDir = chatDirectory(for: characterName)
                    let fileURL = chatDir.appendingPathComponent(filename)

                    let line = try encodeLine(message) + "\n"
                    guard let data = line.data(using: .utf8) else {
                        throw ChatStorageError.encodingFailed
                    }

                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let handle = try FileHandle(forWritingTo: fileURL)
                        defer { handle.closeFile() }
                        handle.seekToEndOfFile()
                        handle.write(data)
                    } else {
                        try data.write(to: fileURL, options: .atomic)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Rewrite an entire chat session to disk (for edits/deletes)
    func rewriteChat(_ session: ChatSession, characterName: String) throws {
        try ioQueue.sync {
            let chatDir = chatDirectory(for: characterName)
            let fileURL = chatDir.appendingPathComponent(session.filename)

            var lines = [try encodeLine(session.metadata)]
            for message in session.messages {
                lines.append(try encodeLine(message))
            }

            let content = lines.joined(separator: "\n") + "\n"
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Async version of rewriteChat that runs file I/O off the main thread
    func rewriteChatAsync(_ session: ChatSession, characterName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ioQueue.async { [self] in
                do {
                    let chatDir = chatDirectory(for: characterName)
                    let fileURL = chatDir.appendingPathComponent(session.filename)

                    var lines = [try encodeLine(session.metadata)]
                    for message in session.messages {
                        lines.append(try encodeLine(message))
                    }

                    let content = lines.joined(separator: "\n") + "\n"
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// List all chat files for a character
    func listChats(for characterName: String) throws -> [(filename: String, date: Date?)] {
        let chatDir = chatDirectory(for: characterName)
        let fm = FileManager.default

        guard fm.fileExists(atPath: chatDir.path) else { return [] }

        let files = try fm.contentsOfDirectory(at: chatDir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "jsonl" }
            .sorted { url1, url2 in
                let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return (date1 ?? .distantPast) > (date2 ?? .distantPast)
            }

        return files.map { url in
            let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return (filename: url.lastPathComponent, date: date)
        }
    }

    /// Delete a chat file
    func deleteChat(characterName: String, filename: String) throws {
        let chatDir = chatDirectory(for: characterName)
        let fileURL = chatDir.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Export a chat to a JSON string
    func exportChat(characterName: String, filename: String) throws -> String {
        let session = try loadChat(characterName: characterName, filename: filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        struct ExportedChat: Codable {
            let metadata: ChatMetadata
            let messages: [ChatMessage]
        }

        let exported = ExportedChat(metadata: session.metadata, messages: session.messages)
        let data = try encoder.encode(exported)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Search chats for a character by message content
    func searchChats(characterName: String, query: String) throws -> [(filename: String, matchingMessages: [ChatMessage])] {
        let chats = try listChats(for: characterName)
        var results: [(filename: String, matchingMessages: [ChatMessage])] = []

        let loweredQuery = query.lowercased()
        for chat in chats {
            if let session = try? loadChat(characterName: characterName, filename: chat.filename) {
                let matches = session.messages.filter {
                    $0.mes.lowercased().contains(loweredQuery)
                }
                if !matches.isEmpty {
                    results.append((filename: chat.filename, matchingMessages: matches))
                }
            }
        }

        return results
    }

    // MARK: - Private Helpers

    private func encodeLine<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let line = String(data: data, encoding: .utf8) else {
            throw ChatStorageError.encodingFailed
        }
        return line
    }
}

enum ChatStorageError: Error, LocalizedError {
    case invalidFormat
    case encodingFailed
    case chatNotFound

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid chat file format"
        case .encodingFailed: return "Failed to encode chat data"
        case .chatNotFound: return "Chat file not found"
        }
    }
}
