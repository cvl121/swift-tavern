import SwiftUI

@main
struct SwiftTavernApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView(appState: appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Character") {
                    NotificationCenter.default.post(name: .newCharacter, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("Chat") {
                Button("Search Messages") {
                    NotificationCenter.default.post(name: .searchMessages, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Chat History") {
                    NotificationCenter.default.post(name: .chatHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Divider()

                Button("Settings") {
                    appState.selectedSidebarItem = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newChat = Notification.Name("com.swifttavern.newChat")
    static let newCharacter = Notification.Name("com.swifttavern.newCharacter")
    static let searchMessages = Notification.Name("com.swifttavern.searchMessages")
    static let chatHistory = Notification.Name("com.swifttavern.chatHistory")
}
