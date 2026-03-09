import SwiftUI
import AppKit

/// Main settings view with sidebar navigation and content pane
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let personaVM: PersonaViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Settings sidebar
            List(viewModel.visibleSections, selection: $viewModel.selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: 180)

            Divider()

            // Settings content
            ScrollView {
                settingsContent
                    .padding(24)
                    .frame(maxWidth: 600, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // Toast overlay
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                toastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { viewModel.showToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showToast)
    }

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(viewModel.toastIsError ? .red : .green)
            Text(viewModel.toastMessage)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 4)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch viewModel.selectedSection {
        case .api:
            apiSection
        case .general:
            generalSection
        case .chat:
            chatSection
        case .generation:
            generationSection
        case .personas:
            personasSection
        case .experimental:
            experimentalSection
        case .data:
            dataSection
        }
    }

    // MARK: - API Provider

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("API Provider")
                .font(.title2.bold())

            // Provider picker - dropdown menu
            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Picker("Provider", selection: $viewModel.selectedAPI) {
                        ForEach(APIType.allCases) { api in
                            Text(api.displayName).tag(api)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                }
                .onChange(of: viewModel.selectedAPI) { _, newValue in
                    viewModel.switchAPI(newValue)
                }
            }

            // API Key
            if viewModel.selectedAPI.requiresAPIKey {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Group {
                            if viewModel.showAPIKey {
                                TextField("Enter API key", text: $viewModel.apiKey)
                            } else {
                                SecureField("Enter API key", text: $viewModel.apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)

                        Button(action: { viewModel.showAPIKey.toggle() }) {
                            Image(systemName: viewModel.showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)

                        Button("Save Key") {
                            viewModel.saveAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            // Model selection with search
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Model")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    if viewModel.isLoadingModels {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Loading models...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                VStack(spacing: 4) {
                    TextField("Search or type model name...", text: $viewModel.modelSearchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 400)
                        .onChange(of: viewModel.modelSearchText) { _, newValue in
                            if viewModel.selectedAPI.defaultModels.contains(newValue) {
                                viewModel.model = newValue
                                viewModel.saveConfiguration()
                            }
                        }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if viewModel.selectedAPI == .openrouter {
                                ForEach(groupedFilteredModels, id: \.provider) { group in
                                    Text(group.provider.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.top, 8)
                                        .padding(.bottom, 2)

                                    ForEach(group.models, id: \.self) { modelName in
                                        modelRow(modelName)
                                    }
                                }
                            } else {
                                ForEach(viewModel.filteredModels, id: \.self) { modelName in
                                    modelRow(modelName)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 400, maxHeight: 200)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)

                    if !viewModel.model.isEmpty {
                        HStack {
                            Text("Selected:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(viewModel.model)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }

            // Base URL
            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL (optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField(viewModel.selectedAPI == .ollama ? "http://localhost:11434" : "Default",
                         text: $viewModel.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)
                    .onSubmit {
                        viewModel.saveConfiguration()
                    }
            }

            Divider()

            // Test Connection
            HStack(spacing: 12) {
                Button("Test Connection") {
                    viewModel.testConnection()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTesting)

                if viewModel.isTesting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Testing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let result = viewModel.connectionTestResult {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.connectionTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.connectionTestSuccess ? .green : .red)
                    Text(result)
                        .font(.caption)
                        .foregroundColor(viewModel.connectionTestSuccess ? .green : .red)
                        .lineLimit(2)
                }
            }

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private struct ModelGroup: Identifiable {
        let provider: String
        let models: [String]
        var id: String { provider }
    }

    private var groupedFilteredModels: [ModelGroup] {
        let filtered = viewModel.filteredModels
        var groups: [String: [String]] = [:]
        for model in filtered {
            let provider = model.components(separatedBy: "/").first ?? "other"
            groups[provider, default: []].append(model)
        }
        return groups.map { ModelGroup(provider: $0.key, models: $0.value) }
            .sorted { $0.provider < $1.provider }
    }

    private func modelRow(_ modelName: String) -> some View {
        Button(action: {
            viewModel.model = modelName
            viewModel.modelSearchText = ""
            viewModel.saveConfiguration()
        }) {
            HStack {
                Text(modelName)
                    .font(.system(size: 12))
                Spacer()
                if viewModel.model == modelName {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(viewModel.model == modelName ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2.bold())

            // Theme
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 250)
                .onChange(of: viewModel.theme) { _, newTheme in
                    viewModel.saveConfiguration()
                    switch newTheme {
                    case .system: NSApp.appearance = nil
                    case .light: NSApp.appearance = NSAppearance(named: .aqua)
                    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("User Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Your name", text: $viewModel.userName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .onSubmit {
                        viewModel.saveConfiguration()
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Default System Prompt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.defaultSystemPrompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                    .onChange(of: viewModel.defaultSystemPrompt) { _, _ in
                        viewModel.saveConfiguration()
                    }
            }

            Divider()

            Toggle("Advanced Mode", isOn: $viewModel.advancedMode)
                .onChange(of: viewModel.advancedMode) { _, _ in
                    viewModel.saveConfiguration()
                }

            Text("Show the Generation parameters tab for fine-tuning model behavior.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Chat

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chat Settings")
                .font(.title2.bold())

            Text("Configure chat input behavior and import presets.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            // Send on Enter toggle
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Send message on Enter", isOn: $viewModel.sendOnEnter)
                    .onChange(of: viewModel.sendOnEnter) { _, _ in
                        viewModel.saveConfiguration()
                    }

                Text(viewModel.sendOnEnter
                     ? "Press Enter to send. Use Shift+Enter for new lines."
                     : "Press Cmd+Enter to send. Enter adds new lines.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Stream response toggle
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Stream responses", isOn: $viewModel.generationParams.streamResponse)
                    .onChange(of: viewModel.generationParams.streamResponse) { _, _ in
                        viewModel.saveConfiguration()
                    }

                Text("Show responses as they are generated. Disable to wait for the full response before displaying.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Import Preset
            VStack(alignment: .leading, spacing: 8) {
                Text("Chat Presets")
                    .font(.headline)

                Text("Import a SillyTavern preset file to load generation parameters (temperature, top_p, etc.).")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Button(action: { viewModel.showingPresetImporter = true }) {
                    Label("Import Preset", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }

            if let status = viewModel.importStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(viewModel.importWasError ? .red : .green)
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingPresetImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importPreset(from: url)
            }
        }
    }

    // MARK: - Generation

    private var generationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Generation Parameters")
                .font(.title2.bold())

            Text("Fine-tune how the AI model generates responses. Changes are saved automatically.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            GenerationSettingsView(params: $viewModel.generationParams)
                .frame(maxWidth: 500)
                .onChange(of: viewModel.generationParams) { _, _ in
                    viewModel.saveConfiguration()
                }
        }
    }

    // MARK: - Personas

    private var personasSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Personas")
                .font(.title2.bold())

            PersonaSettingsView(viewModel: personaVM)
        }
    }

    // MARK: - Experimental

    private var experimentalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Experimental Features")
                .font(.title2.bold())

            Text("These features are in development and may not work as expected.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            Toggle("Enable Experimental Features", isOn: $viewModel.experimentalFeatures)
                .onChange(of: viewModel.experimentalFeatures) { _, _ in
                    viewModel.saveConfiguration()
                }

            if viewModel.experimentalFeatures {
                VStack(alignment: .leading, spacing: 16) {
                    // Group Chats
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Group Chats", isOn: $viewModel.groupChatsEnabled)
                            .onChange(of: viewModel.groupChatsEnabled) { _, _ in
                                viewModel.saveConfiguration()
                            }
                        Text("Enable group chat functionality with multiple characters. Groups will appear in the sidebar conversations list.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    Divider()

                    // Image Generation
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Image Generation", isOn: $viewModel.imageGenerationEnabled)
                            .onChange(of: viewModel.imageGenerationEnabled) { _, _ in
                                viewModel.saveConfiguration()
                            }
                        Text("Generate images within conversations using AI image models. This feature is under development and not yet functional.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        if viewModel.imageGenerationEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Coming Soon")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Image generation settings will appear here in a future update. Supported backends will include DALL-E, Stable Diffusion, and more.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                            .padding(.leading, 20)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        DataImportExportView(viewModel: viewModel)
    }
}

/// View for importing/exporting data from SillyTavern
struct DataImportExportView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Data Import / Export")
                .font(.title2.bold())

            Text("Import your characters, chats, world lore, and presets from an existing SillyTavern installation.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            // SillyTavern path input
            VStack(alignment: .leading, spacing: 8) {
                Text("SillyTavern Installation Path")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("e.g. /Users/you/SillyTavern", text: $viewModel.sillyTavernPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 400)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Select your SillyTavern installation folder"
                        panel.prompt = "Select"
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.sillyTavernPath = url.path
                        }
                    }
                    .controlSize(.small)
                }

                if !viewModel.sillyTavernPath.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Import All SillyTavern Data") {
                        viewModel.importFromPath()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let importStatus = viewModel.importStatusMessage {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.importWasError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(viewModel.importWasError ? .red : .green)
                    Text(importStatus)
                        .font(.caption)
                        .foregroundColor(viewModel.importWasError ? .red : .green)
                }
            }

            Divider()

            Text("Export Data")
                .font(.headline)

            Button("Export All Data") {
                viewModel.exportAllData()
            }
            .buttonStyle(.bordered)
        }
    }
}
