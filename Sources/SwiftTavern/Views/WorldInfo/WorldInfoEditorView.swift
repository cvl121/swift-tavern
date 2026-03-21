import SwiftUI

/// Editor for World Info entries within a book
struct WorldInfoEditorView: View {
    @Binding var book: WorldInfo
    let viewModel: WorldInfoViewModel

    @State private var showDeleteEntryConfirmation = false
    @State private var pendingDeleteEntryUID: Int?
    @State private var entrySearchQuery = ""
    @State private var keywordTestText = ""
    @State private var showKeywordTester = false

    /// Entries filtered by search query, sorted by insertion order
    private var filteredEntries: [WorldInfoEntry] {
        let sorted = book.entries.values.sorted { $0.insertionOrder < $1.insertionOrder }
        let query = entrySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }
        let lowered = query.lowercased()
        return sorted.filter { entry in
            entry.keys.contains { $0.lowercased().contains(lowered) }
            || entry.content.lowercased().contains(lowered)
            || entry.comment.lowercased().contains(lowered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(book.name)
                    .font(.headline)
                Spacer()
                Text("\(book.entries.count) entries")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Button(action: { showKeywordTester.toggle() }) {
                    Label("Test Keywords", systemImage: "magnifyingglass.circle")
                }
                .controlSize(.small)
                .help("Test which entries would activate for a given text")
                Button("Add Entry") {
                    viewModel.addEntry(to: &book)
                }
                .controlSize(.small)
            }
            .padding()

            // Keyword tester
            if showKeywordTester {
                keywordTesterView
                Divider()
            }

            // Search bar
            if book.entries.count > 3 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("Filter entries by keyword or content...", text: $entrySearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !entrySearchQuery.isEmpty {
                        Button(action: { entrySearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            // Entries list
            if book.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No entries yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add an entry to define world lore that activates based on keywords.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add Entry") {
                        viewModel.addEntry(to: &book)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if !entrySearchQuery.isEmpty && filteredEntries.isEmpty {
                            Text("No entries match \"\(entrySearchQuery)\"")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        ForEach(filteredEntries) { entry in
                            entryEditor(entry)
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("Delete Entry", isPresented: $showDeleteEntryConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingDeleteEntryUID = nil
            }
            Button("Delete", role: .destructive) {
                if let uid = pendingDeleteEntryUID {
                    viewModel.removeEntry(uid: uid, from: &book)
                }
                pendingDeleteEntryUID = nil
            }
        } message: {
            Text("Are you sure you want to delete this entry? This cannot be undone.")
        }
    }

    @ViewBuilder
    private func entryEditor(_ entry: WorldInfoEntry) -> some View {
        let key = String(entry.uid)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enabled", isOn: Binding(
                    get: { book.entries[key]?.enabled ?? false },
                    set: { book.entries[key]?.enabled = $0 }
                ))
                .toggleStyle(.checkbox)

                Toggle("Constant", isOn: Binding(
                    get: { book.entries[key]?.constant ?? false },
                    set: { book.entries[key]?.constant = $0 }
                ))
                .toggleStyle(.checkbox)

                Spacer()

                Text("UID: \(entry.uid)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(role: .destructive) {
                    pendingDeleteEntryUID = entry.uid
                    showDeleteEntryConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            // Keywords
            TextField("Keywords (comma-separated)", text: Binding(
                get: { book.entries[key]?.keys.joined(separator: ", ") ?? "" },
                set: { newValue in
                    book.entries[key]?.keys = newValue.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))

            // Content
            TextEditor(text: Binding(
                get: { book.entries[key]?.content ?? "" },
                set: { book.entries[key]?.content = $0 }
            ))
            .font(.system(size: 12))
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(4)

            // Position picker
            Picker("Position", selection: Binding(
                get: { book.entries[key]?.position ?? .beforeChar },
                set: { book.entries[key]?.position = $0 }
            )) {
                ForEach(EntryPosition.allCases, id: \.self) { pos in
                    Text(pos.displayName).tag(pos)
                }
            }
            .pickerStyle(.segmented)
            .font(.system(size: 10))
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onChange(of: book) {
            viewModel.saveBook(book)
        }
    }

    // MARK: - Keyword Tester

    /// Entries that would activate for the test text
    private var matchingEntries: [WorldInfoEntry] {
        let text = keywordTestText.lowercased()
        guard !text.isEmpty else { return [] }
        return book.entries.values
            .filter { entry in
                guard entry.enabled else { return false }
                if entry.constant { return true }
                return entry.keys.contains { key in
                    !key.isEmpty && text.contains(key.lowercased())
                }
            }
            .sorted { $0.insertionOrder < $1.insertionOrder }
    }

    private var keywordTesterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyword Tester")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("Enter sample text to test which entries would activate...", text: $keywordTestText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            if !keywordTestText.isEmpty {
                if matchingEntries.isEmpty {
                    Text("No entries would activate for this text.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(matchingEntries.count) entries would activate:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                        ForEach(matchingEntries) { entry in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(entry.constant ? Color.blue : Color.green)
                                    .frame(width: 6, height: 6)
                                Text(entry.keys.joined(separator: ", "))
                                    .font(.system(size: 11, weight: .medium))
                                if entry.constant {
                                    Text("(constant)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Text(entry.content.prefix(60) + (entry.content.count > 60 ? "..." : ""))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }
}
