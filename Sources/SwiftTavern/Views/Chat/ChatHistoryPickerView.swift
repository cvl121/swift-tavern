import SwiftUI

/// Picker to switch between chat sessions
struct ChatHistoryPickerView: View {
    let chatList: [(filename: String, date: Date?)]
    let currentFilename: String?
    let onSelect: (String) -> Void
    let onNew: () -> Void
    let onDelete: () -> Void

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
                Text("No chat history")
                    .foregroundColor(.secondary)
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
