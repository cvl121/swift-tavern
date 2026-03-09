import Foundation

/// Service for managing group chat history files (JSONL format)
final class GroupChatStorageService {
    private let directoryManager: DataDirectoryManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
    }

    /// Create a new group chat session
    func createChat(groupName: String, userName: String) throws -> ChatSession {
        let chatId = Date().chatFileDateString
        let filename = "\(groupName.sanitizedFilename()) - \(chatId).jsonl"
        let fileURL = directoryManager.groupChatsDirectory.appendingPathComponent(filename)

        let metadata = ChatMetadata(
            userName: userName,
            characterName: groupName,
            chatMetadata: ChatMetadataInfo(),
            createDate: Date().sillyTavernDateString
        )

        let line = try encodeLine(metadata) + "\n"
        try line.write(to: fileURL, atomically: true, encoding: .utf8)

        return ChatSession(
            id: chatId,
            filename: filename,
            metadata: metadata,
            messages: []
        )
    }

    /// Load a group chat session
    func loadChat(filename: String) throws -> ChatSession {
        let fileURL = directoryManager.groupChatsDirectory.appendingPathComponent(filename)

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

    /// Append a message to a group chat
    func appendMessage(_ message: ChatMessage, filename: String) throws {
        let fileURL = directoryManager.groupChatsDirectory.appendingPathComponent(filename)

        let line = try encodeLine(message) + "\n"
        guard let data = line.data(using: .utf8) else {
            throw ChatStorageError.encodingFailed
        }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    /// List all group chat files
    func listChats() throws -> [(filename: String, date: Date?)] {
        let dir = directoryManager.groupChatsDirectory
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path) else { return [] }

        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
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

    /// Delete a group chat
    func deleteChat(filename: String) throws {
        let fileURL = directoryManager.groupChatsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }

    private func encodeLine<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let line = String(data: data, encoding: .utf8) else {
            throw ChatStorageError.encodingFailed
        }
        return line
    }
}
