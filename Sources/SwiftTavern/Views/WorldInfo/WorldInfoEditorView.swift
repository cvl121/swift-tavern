import SwiftUI

/// Editor for World Info entries within a book
struct WorldInfoEditorView: View {
    @Binding var book: WorldInfo
    let viewModel: WorldInfoViewModel

    @State private var showDeleteEntryConfirmation = false
    @State private var pendingDeleteEntryUID: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(book.name)
                    .font(.headline)
                Spacer()
                Button("Add Entry") {
                    viewModel.addEntry(to: &book)
                }
                .controlSize(.small)
            }
            .padding()

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
                        let sortedEntries = book.entries.values.sorted { $0.insertionOrder < $1.insertionOrder }
                        ForEach(sortedEntries) { entry in
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
}
