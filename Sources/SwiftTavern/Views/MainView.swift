import SwiftUI
import AppKit

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
    @State private var showGlobalSearch = false
    @State private var sidebarVisible = true
    @State private var sidebarWidth: CGFloat = 250
    @State private var dragStartWidth: CGFloat = 250

    init(appState: AppState? = nil) {
        let state = appState ?? AppState()
        _appState = State(initialValue: state)
        _characterListVM = State(initialValue: CharacterListViewModel(appState: state))
        _chatVM = State(initialValue: ChatViewModel(appState: state))
        _settingsVM = State(initialValue: SettingsViewModel(appState: state))
        _worldInfoVM = State(initialValue: WorldInfoViewModel(appState: state))
        _personaVM = State(initialValue: PersonaViewModel(appState: state))
        _groupChatVM = State(initialValue: GroupChatViewModel(appState: state))
        _sidebarVisible = State(initialValue: state.settings.sidebarVisible)
        _sidebarWidth = State(initialValue: CGFloat(state.settings.sidebarWidth))
        _dragStartWidth = State(initialValue: CGFloat(state.settings.sidebarWidth))
    }

    private let minSidebarWidth: CGFloat = 220
    private let maxSidebarWidth: CGFloat = 400
    private let minContentWidth: CGFloat = 500

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
                .background(.ultraThinMaterial)
                .transition(.move(edge: .leading))

                // Resizable divider handle
                Rectangle()
                    .fill(Color(.separatorColor))
                    .frame(width: 1)
                    .overlay(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 8)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.resizeLeftRight.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .gesture(
                                DragGesture(coordinateSpace: .global)
                                    .onChanged { value in
                                        let newWidth = dragStartWidth + value.translation.width
                                        sidebarWidth = min(maxSidebarWidth, max(minSidebarWidth, newWidth))
                                    }
                                    .onEnded { _ in
                                        dragStartWidth = sidebarWidth
                                        appState.settings.sidebarWidth = Double(sidebarWidth)
                                    }
                            )
                    )
            }

            // Detail content
            VStack(spacing: 0) {
                // Slim top bar with sidebar toggle and global search
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            sidebarVisible.toggle()
                            appState.settings.sidebarVisible = sidebarVisible
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Sidebar")
                    .padding(.leading, sidebarVisible ? 8 : 76)

                    Spacer()

                    Button(action: { showGlobalSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Global Search (Cmd+Shift+F)")
                    .padding(.trailing, 8)
                }
                .frame(height: 32)
                .background(Color(.windowBackgroundColor).opacity(0.8))

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: minContentWidth)
        }
        .frame(minWidth: minSidebarWidth + minContentWidth + 1, minHeight: 600)
        .applyUIScale(appState.settings.uiScale)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: sidebarVisible)
        .clipped()
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: appState.toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(appState.toastIsError ? .red : .green)
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.toastMessage != nil)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            appState.loadAll()
            settingsVM.applyTheme()
            if !appState.settings.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(
                onDismiss: {
                    appState.settings.hasCompletedOnboarding = true
                    appState.saveSettings()
                    showOnboarding = false
                },
                onSetUpAPI: {
                    appState.selectedSidebarItem = .settings
                    settingsVM.selectedSection = .api
                }
            )
        }
        .sheet(isPresented: $groupChatVM.showingGroupEditor) {
            GroupEditorView(appState: appState, groupChatVM: groupChatVM)
        }
        .sheet(isPresented: $showGlobalSearch) {
            GlobalSearchView(
                appState: appState,
                onDismiss: { showGlobalSearch = false },
                onNavigate: { entry, chatFilename in
                    showGlobalSearch = false
                    characterListVM.selectCharacter(entry)
                    if let chatFilename = chatFilename {
                        // Load the specific chat
                        let charName = entry.card.data.name
                        if let session = try? appState.chatStorage.loadChat(
                            characterName: charName,
                            filename: chatFilename
                        ) {
                            appState.currentChat = session
                        }
                    }
                }
            )
            .frame(minWidth: 600, minHeight: 500)
        }
        .onReceive(NotificationCenter.default.publisher(for: .globalSearch)) { _ in
            showGlobalSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            showOnboarding = true
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
            VStack(spacing: 0) {
                detailContent
                if appState.settings.developerMode {
                    Divider()
                    DevLogView(appState: appState)
                        .frame(height: 160)
                }
            }
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

        case .characterInfo(let filename):
            if let entry = appState.characters.first(where: { $0.filename == filename }) {
                CharacterEditorWrapper(
                    appState: appState,
                    entry: entry,
                    onDelete: { characterListVM.requestDeleteCharacter(entry) },
                    onBack: { appState.selectedSidebarItem = .characters }
                )
                .id(filename)
            } else {
                welcomeView
            }

        case .newCharacter:
            CharacterEditorWrapper(
                appState: appState,
                entry: nil,
                onBack: { appState.selectedSidebarItem = .characters }
            )
            .id("new-character")

        case .settings:
            SettingsView(viewModel: settingsVM, personaVM: personaVM)

        case .worldLore:
            WorldInfoListView(viewModel: worldInfoVM)

        case .personas:
            PersonaPageView(personaVM: personaVM, appState: appState)

        case nil:
            welcomeView
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52))
                .foregroundStyle(.linearGradient(
                    colors: [.accentColor.opacity(0.6), .accentColor.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 6) {
                Text("SwiftTavern")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                Text("Select a character to start chatting, or create a new one.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: { appState.selectedSidebarItem = .newCharacter }) {
                    Label("New Character", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: { characterListVM.showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Wrapper that owns the CharacterEditorViewModel as @State so it persists across re-renders
private struct CharacterEditorWrapper: View {
    let appState: AppState
    let entry: CharacterEntry?
    var onDelete: (() -> Void)?
    var onBack: (() -> Void)?

    @State private var viewModel: CharacterEditorViewModel?

    var body: some View {
        if let vm = viewModel {
            CharacterEditorView(
                viewModel: vm,
                onDelete: onDelete,
                onBack: onBack
            )
        } else {
            Color.clear.onAppear {
                viewModel = CharacterEditorViewModel(appState: appState, character: entry)
            }
        }
    }
}
