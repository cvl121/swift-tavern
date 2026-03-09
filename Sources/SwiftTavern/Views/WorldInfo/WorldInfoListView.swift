import SwiftUI

/// List of World Lore books
struct WorldInfoListView: View {
    @Bindable var viewModel: WorldInfoViewModel

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

                Button("New Book") {
                    viewModel.showingNewBookDialog = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(20)

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
                HSplitView {
                    // Book list
                    List(viewModel.books) { book in
                        HStack {
                            Text(book.name)
                            Spacer()
                            Text("\(book.entries.count) entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedBook = book
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteBook(book)
                            }
                        }
                    }
                    .frame(minWidth: 200)

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
        .fileImporter(
            isPresented: $viewModel.showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importWorldLore(from: url)
            }
        }
    }
}
