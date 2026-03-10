import SwiftUI

/// Developer log panel showing API request/response metadata
struct DevLogView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Developer Log")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(appState.devLogger.entries.count) entries")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Button("Clear") {
                    appState.devLogger.clear()
                }
                .controlSize(.mini)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.devLogger.entries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.formattedTimestamp)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 75, alignment: .leading)

                                Text(entry.type.rawValue)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(colorForType(entry.type))
                                    .frame(width: 35, alignment: .leading)

                                Text(entry.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .id(entry.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: appState.devLogger.entries.count) {
                    if let last = appState.devLogger.entries.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.5))
    }

    private func colorForType(_ type: DevLogger.LogEntry.LogType) -> Color {
        switch type {
        case .request: return .blue
        case .response: return .green
        case .error: return .red
        case .info: return .orange
        }
    }
}
