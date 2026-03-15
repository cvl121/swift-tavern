import SwiftUI

/// Picker to switch between chat sessions
struct ChatHistoryPickerView: View {
    let chatList: [(filename: String, date: Date?)]
    let currentFilename: String?
    let onSelect: (String) -> Void
    let onNew: () -> Void
    let onDelete: () -> Void
    var onDeleteChat: ((String) -> Void)? = nil

    @State private var hoveredChat: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chat History")
                    .font(.headline)
                Spacer()
                Button("New Chat", action: onNew)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            if chatList.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No chat history")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Start a conversation to see it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(chatList, id: \.filename) { chat in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(chat.filename)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                if let date = chat.date {
                                    Text(date.relativeDisplayString)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if chat.filename == currentFilename {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(chat.filename)
                        }
                        .onHover { hovering in
                            hoveredChat = hovering ? chat.filename : nil
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(hoveredChat == chat.filename ? Color.primary.opacity(0.06) : Color.clear)
                        )
                        .contextMenu {
                            Button("Load Chat") {
                                onSelect(chat.filename)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                onDeleteChat?(chat.filename)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Delete Current Chat", role: .destructive, action: onDelete)
                    .controlSize(.small)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}
