import SwiftUI

@main
struct SwiftTavernApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView(appState: appState)
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Character") {
                    appState.selectedSidebarItem = .newCharacter
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)

                Button("Show Onboarding") {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                }
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

                Button("Regenerate Response") {
                    NotificationCenter.default.post(name: .regenerateResponse, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Global Search") {
                    NotificationCenter.default.post(name: .globalSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

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
    static let regenerateResponse = Notification.Name("com.swifttavern.regenerateResponse")
    static let globalSearch = Notification.Name("com.swifttavern.globalSearch")
    static let showOnboarding = Notification.Name("com.swifttavern.showOnboarding")
    static let showKeyboardShortcuts = Notification.Name("com.swifttavern.showKeyboardShortcuts")
}
