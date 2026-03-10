import SwiftUI
import Combine

/// Reusable search field with optional debounce
struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var debounceInterval: TimeInterval = 0

    @State private var localText: String = ""
    @State private var debounceTask: DispatchWorkItem?

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: debounceInterval > 0 ? $localText : $text)
                .textFieldStyle(.plain)
                .onChange(of: localText) { _, newValue in
                    guard debounceInterval > 0 else { return }
                    debounceTask?.cancel()
                    let task = DispatchWorkItem { text = newValue }
                    debounceTask = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: task)
                }
            if !(debounceInterval > 0 ? localText : text).isEmpty {
                Button(action: {
                    text = ""
                    localText = ""
                    debounceTask?.cancel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear { localText = text }
    }
}
