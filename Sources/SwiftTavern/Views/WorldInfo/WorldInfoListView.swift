import SwiftUI
import UniformTypeIdentifiers

/// List of World Lore books
struct WorldInfoListView: View {
    @Bindable var viewModel: WorldInfoViewModel
    @State private var isDropTargeted = false

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    if url.pathExtension.lowercased() == "json" {
                        DispatchQueue.main.async {
                            viewModel.importWorldLore(from: url)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("World Lore")
                    .font(.title2.bold())
                Spacer()
                Button(action: { viewModel.showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let book = viewModel.selectedBook {
                    Button(action: { viewModel.exportBook(book) }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: { viewModel.showingNewBookDialog = true }) {
                    Label("New Book", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Active world lore status
            if viewModel.activeWorldLoreName != nil || viewModel.globalWorldLoreName != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let charLore = viewModel.characterWorldLoreName {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("Character:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(charLore)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                            if let name = viewModel.selectedCharacterName {
                                Text("(\(name))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if let globalLore = viewModel.globalWorldLoreName {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Global:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(globalLore)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                            if viewModel.characterWorldLoreName != nil {
                                Text("(overridden)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            Divider()

            if viewModel.books.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No World Lore books")
                        .foregroundColor(.secondary)
                    Text("Create a book to add context that activates based on keywords in the conversation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                HStack(spacing: 0) {
                    // Book list (fixed narrow width)
                    VStack(spacing: 0) {
                        List(viewModel.books) { book in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(book.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        if viewModel.characterWorldLoreName == book.name {
                                            Text("Active")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.blue)
                                                .cornerRadius(3)
                                        } else if viewModel.characterWorldLoreName == nil && viewModel.globalWorldLoreName == book.name {
                                            Text("Global")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.green)
                                                .cornerRadius(3)
                                        }
                                    }
                                    Text("\(book.entries.count) entries")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .listRowBackground(
                                viewModel.selectedBook?.name == book.name
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .help(book.name)
                            .onTapGesture {
                                viewModel.selectedBook = book
                            }
                            .contextMenu {
                                Button("Edit") {
                                    viewModel.selectedBook = book
                                }
                                Button("Export") {
                                    viewModel.exportBook(book)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteBook(book)
                                }
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                    }
                    .frame(width: 200)

                    Divider()

                    // Book editor
                    if var book = viewModel.selectedBook {
                        WorldInfoEditorView(book: Binding(
                            get: { book },
                            set: { newValue in
                                book = newValue
                                viewModel.saveBook(newValue)
                            }
                        ), viewModel: viewModel)
                    } else {
                        Text("Select a book")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onDrop(of: [.json, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    .background(Color.accentColor.opacity(0.08))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 32))
                                .foregroundColor(.accentColor)
                            Text("Drop to Import World Lore")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(4)
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importWorldLore(from: url)
            }
        }
        .alert("New World Lore Book", isPresented: Binding(
            get: { viewModel.showingNewBookDialog },
            set: { viewModel.showingNewBookDialog = $0 }
        )) {
            TextField("Book name", text: Binding(
                get: { viewModel.newBookName },
                set: { viewModel.newBookName = $0 }
            ))
            Button("Cancel", role: .cancel) {}
            Button("Create") { viewModel.createBook() }
        }
    }
}
