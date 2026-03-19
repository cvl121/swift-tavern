import SwiftUI

/// A search result representing a match in a character's chat
struct GlobalSearchResult: Identifiable {
    let id = UUID()
    let characterEntry: CharacterEntry
    let chatFilename: String
    let message: ChatMessage
}

/// Global search overlay that searches across all characters and conversations
struct GlobalSearchView: View {
    let appState: AppState
    let onDismiss: () -> Void
    let onNavigate: (CharacterEntry, String?) -> Void

    @State private var searchText = ""
    @State private var results: [String: [GlobalSearchResult]] = [:]
    @State private var matchingCharacters: [CharacterEntry] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))

                TextField("Search characters and messages...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isSearchFieldFocused)
                    .onSubmit { performSearch() }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        results = [:]
                        matchingCharacters = []
                        hasSearched = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            if isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasSearched {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Search across all characters and conversations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Press Return to search")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matchingCharacters.isEmpty && results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Character name matches
                        if !matchingCharacters.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Characters")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)

                                ForEach(matchingCharacters) { entry in
                                    Button(action: { onNavigate(entry, nil) }) {
                                        HStack(spacing: 10) {
                                            AvatarImageView(
                                                imageData: entry.avatarData,
                                                name: entry.card.data.name,
                                                size: 32
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.card.data.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                if !entry.card.data.description.isEmpty {
                                                    Text(entry.card.data.description)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(8)
                                        .background(Color(.controlBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Chat message matches grouped by character
                        let sortedKeys = results.keys.sorted()
                        ForEach(sortedKeys, id: \.self) { charName in
                            if let charResults = results[charName], !charResults.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        if let entry = charResults.first?.characterEntry {
                                            AvatarImageView(
                                                imageData: entry.avatarData,
                                                name: entry.card.data.name,
                                                size: 24
                                            )
                                        }
                                        Text(charName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text("\(charResults.count) match\(charResults.count == 1 ? "" : "es")")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 4)

                                    ForEach(charResults.prefix(10)) { result in
                                        Button(action: {
                                            onNavigate(result.characterEntry, result.chatFilename)
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Text(result.message.name)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(result.message.isUser ? .accentColor : .primary)
                                                    Spacer()
                                                    Text(result.message.sendDate)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                }
                                                Text(highlightedSnippet(result.message.mes))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(3)
                                            }
                                            .padding(8)
                                            .background(Color(.controlBackgroundColor))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if charResults.count > 10 {
                                        Text("... and \(charResults.count - 10) more results")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    private func highlightedSnippet(_ text: String) -> String {
        let query = searchText.lowercased()
        guard let range = text.lowercased().range(of: query) else {
            return String(text.prefix(200))
        }

        let matchStart = text.distance(from: text.startIndex, to: range.lowerBound)
        let snippetStart = max(0, matchStart - 40)
        let startIndex = text.index(text.startIndex, offsetBy: snippetStart)
        let endIndex = text.index(startIndex, offsetBy: min(200, text.distance(from: startIndex, to: text.endIndex)))
        var snippet = String(text[startIndex..<endIndex])
        if snippetStart > 0 { snippet = "..." + snippet }
        if endIndex < text.endIndex { snippet = snippet + "..." }
        return snippet
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        hasSearched = true

        Task.detached {
            let loweredQuery = query.lowercased()
            let characters = await MainActor.run { appState.characters }
            let chatStorage = await MainActor.run { appState.chatStorage }

            // Search character names
            let charMatches = characters.filter {
                $0.card.data.name.lowercased().contains(loweredQuery)
            }

            // Search chat messages across all characters
            var searchedResults: [String: [GlobalSearchResult]] = [:]
            for entry in characters {
                let charName = entry.card.data.name
                if let searchMatches = try? chatStorage.searchChats(characterName: charName, query: query) {
                    var charResultList: [GlobalSearchResult] = []
                    for match in searchMatches {
                        for message in match.matchingMessages {
                            charResultList.append(GlobalSearchResult(
                                characterEntry: entry,
                                chatFilename: match.filename,
                                message: message
                            ))
                        }
                    }
                    if !charResultList.isEmpty {
                        searchedResults[charName] = charResultList
                    }
                }
            }

            let finalResults = searchedResults
            await MainActor.run {
                matchingCharacters = charMatches
                results = finalResults
                isSearching = false
            }
        }
    }
}
