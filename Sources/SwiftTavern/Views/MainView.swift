import SwiftUI

/// Main application view with custom sidebar layout
struct MainView: View {
    @State var appState: AppState
    @State private var characterListVM: CharacterListViewModel
    @State private var chatVM: ChatViewModel
    @State private var settingsVM: SettingsViewModel
    @State private var worldInfoVM: WorldInfoViewModel
    @State private var personaVM: PersonaViewModel
    @State private var groupChatVM: GroupChatViewModel
    @State private var showOnboarding = false
    @State private var sidebarVisible = true
    @State private var sidebarWidth: CGFloat = 250

    init(appState: AppState? = nil) {
        let state = appState ?? AppState()
        _appState = State(initialValue: state)
        _characterListVM = State(initialValue: CharacterListViewModel(appState: state))
        _chatVM = State(initialValue: ChatViewModel(appState: state))
        _settingsVM = State(initialValue: SettingsViewModel(appState: state))
        _worldInfoVM = State(initialValue: WorldInfoViewModel(appState: state))
        _personaVM = State(initialValue: PersonaViewModel(appState: state))
        _groupChatVM = State(initialValue: GroupChatViewModel(appState: state))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if sidebarVisible {
                SidebarView(
                    appState: appState,
                    characterListVM: characterListVM,
                    groupChatVM: groupChatVM
                )
                .frame(width: sidebarWidth)
                .frame(minWidth: 200, maxWidth: 350)
                .transition(.move(edge: .leading))

                Divider()
            }

            // Detail content
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sidebarVisible.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }
        }
        .navigationTitle("")
        .frame(minWidth: 1000, minHeight: 600)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            appState.loadAll()
            settingsVM.applyTheme()
            if !appState.settings.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                appState.settings.hasCompletedOnboarding = true
                appState.saveSettings()
                showOnboarding = false
            }
        }
        .sheet(isPresented: $characterListVM.showingCreator) {
            CharacterEditorView(viewModel: CharacterEditorViewModel(appState: appState))
        }
        .sheet(isPresented: $characterListVM.showingEditor) {
            if let entry = characterListVM.editingEntry {
                CharacterEditorView(
                    viewModel: CharacterEditorViewModel(appState: appState, character: entry),
                    onDelete: {
                        characterListVM.requestDeleteCharacter(entry)
                    }
                )
            }
        }
        .sheet(isPresented: $groupChatVM.showingGroupEditor) {
            GroupEditorView(appState: appState, groupChatVM: groupChatVM)
        }
        .fileImporter(
            isPresented: $characterListVM.showingImporter,
            allowedContentTypes: [.png, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                characterListVM.importCharacter(from: url)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            detailContent
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedSidebarItem {
        case .character:
            if appState.selectedCharacter != nil, appState.currentChat != nil {
                ChatView(appState: appState, chatVM: chatVM)
            } else if let character = appState.selectedCharacter {
                CharacterDetailView(entry: character)
            } else {
                welcomeView
            }

        case .group:
            if appState.selectedGroup != nil {
                GroupChatView(appState: appState, groupChatVM: groupChatVM)
            } else {
                welcomeView
            }

        case .characters:
            CharacterListView(appState: appState, characterListVM: characterListVM)

        case .settings:
            SettingsView(viewModel: settingsVM, personaVM: personaVM)

        case .worldLore:
            WorldInfoListView(viewModel: worldInfoVM)

        case .personas:
            PersonaPageView(personaVM: personaVM)

        case nil:
            welcomeView
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("SwiftTavern")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Select a character to start chatting, or create a new one.")
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("New Character") {
                    characterListVM.showingCreator = true
                }
                .buttonStyle(.borderedProminent)

                Button("Import Character") {
                    characterListVM.showingImporter = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
