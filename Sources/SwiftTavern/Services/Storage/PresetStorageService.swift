import Foundation

/// Service for managing chat presets on disk (JSON files in presets/ directory)
final class PresetStorageService {
    private let directoryManager: DataDirectoryManager

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
    }

    private var presetsDirectory: URL {
        directoryManager.url(for: "presets")
    }

    /// Load all presets. Always includes "Default" even if no file exists.
    func loadAll() -> [ChatPreset] {
        let fm = FileManager.default
        let dir = presetsDirectory

        // Ensure directory exists
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "json" }) else {
            return [.default]
        }

        var presets: [ChatPreset] = []
        for file in files {
            if let data = try? Data(contentsOf: file),
               let preset = try? JSONDecoder().decode(ChatPreset.self, from: data) {
                presets.append(preset)
            }
        }

        // Ensure Default preset always exists
        if !presets.contains(where: { $0.name == "Default" }) {
            presets.insert(.default, at: 0)
            try? save(.default)
        }

        return presets.sorted { $0.name == "Default" ? true : ($1.name == "Default" ? false : $0.name < $1.name) }
    }

    /// Save a preset to disk
    func save(_ preset: ChatPreset) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)

        let filename = preset.name.sanitizedFilename() + ".json"
        let fileURL = presetsDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preset)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Delete a preset from disk
    func delete(name: String) throws {
        let filename = name.sanitizedFilename() + ".json"
        let fileURL = presetsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Import a SillyTavern preset JSON file, returning a ChatPreset
    func importFromSillyTavern(url: URL) throws -> ChatPreset {
        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "PresetStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid preset file format"])
        }

        let name = (dict["name"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        var params = GenerationParameters.default

        if let v = dict["temperature"] as? Double { params.temperature = v }
        if let v = dict["top_p"] as? Double { params.topP = v }
        if let v = dict["top_k"] as? Int { params.topK = v }
        else if let v = dict["top_k"] as? Double { params.topK = Int(v) }

        if let v = dict["max_tokens"] as? Int { params.maxTokens = v }
        else if let v = dict["max_length"] as? Int { params.maxTokens = v }
        else if let v = dict["genamt"] as? Int { params.maxTokens = v }

        if let v = dict["frequency_penalty"] as? Double { params.frequencyPenalty = v }
        else if let v = dict["freq_pen"] as? Double { params.frequencyPenalty = v }

        if let v = dict["presence_penalty"] as? Double { params.presencePenalty = v }
        else if let v = dict["presence_pen"] as? Double { params.presencePenalty = v }

        if let v = dict["repetition_penalty"] as? Double { params.repetitionPenalty = v }
        else if let v = dict["rep_pen"] as? Double { params.repetitionPenalty = v }

        if let v = dict["stream"] as? Bool { params.streamResponse = v }

        return ChatPreset(name: name, generationParams: params)
    }

    /// Export a preset in SillyTavern-compatible format
    func exportAsSillyTavern(_ preset: ChatPreset) throws -> Data {
        let p = preset.generationParams
        let dict: [String: Any] = [
            "name": preset.name,
            "temperature": p.temperature,
            "top_p": p.topP,
            "top_k": p.topK,
            "max_tokens": p.maxTokens,
            "max_length": p.maxTokens,
            "frequency_penalty": p.frequencyPenalty,
            "presence_penalty": p.presencePenalty,
            "repetition_penalty": p.repetitionPenalty,
            "stream": p.streamResponse,
        ]
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }
}
