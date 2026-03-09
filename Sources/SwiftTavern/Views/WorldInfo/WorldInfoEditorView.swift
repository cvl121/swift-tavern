import SwiftUI

/// Editor for World Info entries within a book
struct WorldInfoEditorView: View {
    @Binding var book: WorldInfo
    let viewModel: WorldInfoViewModel

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

    @ViewBuilder
    private func entryEditor(_ entry: WorldInfoEntry) -> some View {
        let key = String(entry.uid)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enabled", isOn: Binding(
                    get: { book.entries[key]?.enabled ?? true },
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
                    viewModel.removeEntry(uid: entry.uid, from: &book)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            // Comment/Name
            TextField("Comment/Name", text: Binding(
                get: { book.entries[key]?.comment ?? "" },
                set: { book.entries[key]?.comment = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))

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
            .frame(minHeight: 60)
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
                    Text(pos.rawValue).tag(pos)
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
