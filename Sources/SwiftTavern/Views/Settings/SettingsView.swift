import SwiftUI
import AppKit

/// Main settings view with sidebar navigation and content pane
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let personaVM: PersonaViewModel

    @State private var settingsSidebarWidth: CGFloat = 180
    @State private var settingsDragStartWidth: CGFloat = 180

    var body: some View {
        HStack(spacing: 0) {
            // Settings sidebar
            List(viewModel.visibleSections, selection: $viewModel.selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: settingsSidebarWidth)

            // Resizable divider
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
                                    let newWidth = settingsDragStartWidth + value.translation.width
                                    settingsSidebarWidth = min(max(newWidth, 150), 250)
                                }
                                .onEnded { _ in
                                    settingsDragStartWidth = settingsSidebarWidth
                                }
                        )
                )

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
        .fileImporter(
            isPresented: $viewModel.showingPresetImporterFile,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importPresetFile(from: url)
            }
        }
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
        case .presets:
            presetsSection
        case .experimental:
            experimentalSection
        case .data:
            dataSection
        case .reset:
            resetSection
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

            // UI Scale
            VStack(alignment: .leading, spacing: 6) {
                Text("UI Text Size")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $viewModel.uiScale, in: 0.75...1.5, step: 0.05)
                        .frame(maxWidth: 250)
                    Text("\(Int(viewModel.uiScale * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                    Button("Reset") {
                        viewModel.uiScale = 1.0
                        viewModel.saveConfiguration()
                    }
                    .controlSize(.small)
                    .disabled(viewModel.uiScale == 1.0)
                }
                .onChange(of: viewModel.uiScale) { _, _ in
                    viewModel.saveConfiguration()
                }
                Text("Scale the app's text size. Does not affect chat message text (use Chat Style for that).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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

            // Global World Lore
            VStack(alignment: .leading, spacing: 6) {
                Text("Global World Lore")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("World Lore", selection: $viewModel.globalWorldLore) {
                    Text("None").tag(String?.none)
                    ForEach(viewModel.worldInfoBookNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: viewModel.globalWorldLore) { _, _ in
                    viewModel.saveConfiguration()
                }

                Text("Default world lore applied to all characters unless overridden per-character in the character editor.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Global Chat Style
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Chat Style")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Default text styling for all conversations. Individual conversations can override this via the Style button in the chat header.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                globalChatStyleEditor
            }

            Divider()

            Toggle("Advanced Mode", isOn: $viewModel.advancedMode)
                .onChange(of: viewModel.advancedMode) { _, _ in
                    viewModel.saveConfiguration()
                }

            Text("Show the Chat Presets tab for fine-tuning model behavior.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private var globalChatStyleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Font size
            HStack {
                Text("Font Size")
                    .font(.system(size: 12))
                Spacer()
                TextField("", value: $viewModel.chatStyle.fontSize, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
            }
            Slider(value: $viewModel.chatStyle.fontSize, in: 10...24, step: 1)
                .frame(maxWidth: 300)

            HStack(spacing: 16) {
                globalColorPicker(
                    title: "Dialogue",
                    color: $viewModel.chatStyle.quotedTextColor
                )
                globalColorPicker(
                    title: "Actions",
                    color: $viewModel.chatStyle.italicActionColor
                )
                globalColorPicker(
                    title: "Narrative",
                    color: $viewModel.chatStyle.narrativeColor
                )
            }

            // Preview
            VStack(alignment: .leading, spacing: 4) {
                MarkdownTextView(
                    text: "*She leans against the doorframe.* *\"Hey there!\"* She smiles warmly.",
                    chatStyle: viewModel.chatStyle
                )
                .font(.system(size: viewModel.chatStyle.fontSize))
            }
            .padding(10)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    viewModel.chatStyle = .default
                    viewModel.saveConfiguration()
                }
                .controlSize(.small)
            }
        }
        .onChange(of: viewModel.chatStyle) { _, _ in
            viewModel.saveConfiguration()
        }
    }

    @ViewBuilder
    private func globalColorPicker(title: String, color: Binding<CodableColor>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11))
            ColorPicker("", selection: Binding(
                get: { Color(red: color.wrappedValue.r, green: color.wrappedValue.g, blue: color.wrappedValue.b, opacity: color.wrappedValue.a) },
                set: { newColor in
                    if let components = NSColor(newColor).usingColorSpace(.sRGB) {
                        color.wrappedValue = CodableColor(
                            r: Double(components.redComponent),
                            g: Double(components.greenComponent),
                            b: Double(components.blueComponent),
                            a: Double(components.alphaComponent)
                        )
                    }
                }
            ))
            .labelsHidden()
        }
    }

    // MARK: - Chat

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chat Settings")
                .font(.title2.bold())

            Text("Configure chat input behavior.")
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

            // Show chat button labels
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show chat button labels", isOn: $viewModel.showChatButtonLabels)
                    .onChange(of: viewModel.showChatButtonLabels) { _, _ in
                        viewModel.saveConfiguration()
                    }

                Text("Display text labels next to the chat action buttons in the header.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Chat display limits
            VStack(alignment: .leading, spacing: 6) {
                Text("Chat Display Limits")
                    .font(.system(size: 12, weight: .medium))

                HStack {
                    Text("Max messages shown")
                        .font(.system(size: 12))
                    Spacer()
                    TextField("0 = all", value: $viewModel.chatDisplayLimit, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.chatDisplayLimit) { _, _ in
                            viewModel.saveConfiguration()
                        }
                }

                HStack {
                    Text("Max message length (chars)")
                        .font(.system(size: 12))
                    Spacer()
                    TextField("0 = all", value: $viewModel.chatMessageLengthLimit, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.chatMessageLengthLimit) { _, _ in
                            viewModel.saveConfiguration()
                        }
                }

                Text("Limit how many messages and how long each message is displayed in the chat. Useful for long conversations. Set to 0 for unlimited.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Developer mode
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Developer Mode", isOn: $viewModel.developerMode)
                    .onChange(of: viewModel.developerMode) { _, _ in
                        viewModel.saveConfiguration()
                    }

                Text("Show a developer log panel with API request and response metadata for debugging.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if let status = viewModel.importStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(viewModel.importWasError ? .red : .green)
            }
        }
    }

    // MARK: - Chat Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chat Presets")
                .font(.title2.bold())

            Text("Manage generation parameter presets. Changes are saved when you click Update.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Preset selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Preset")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Picker("Preset", selection: $viewModel.activePresetName) {
                        ForEach(viewModel.presetList, id: \.name) { preset in
                            Text(preset.name).tag(preset.name)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: viewModel.activePresetName) { _, newValue in
                        viewModel.selectPreset(newValue)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("New") {
                        viewModel.showingNewPresetDialog = true
                    }
                    .controlSize(.small)

                    Button("Update") {
                        viewModel.updateCurrentPreset()
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        viewModel.deleteCurrentPreset()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.activePresetName == "Default")
                    .help(viewModel.activePresetName == "Default" ? "Cannot delete Default preset" : "Delete preset")
                }
            }

            Divider()

            // Import/Export
            HStack(spacing: 8) {
                Button(action: { viewModel.showingPresetImporterFile = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { viewModel.exportCurrentPreset() }) {
                    Label("Export Selected", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { viewModel.exportAllPresets() }) {
                    Label("Export All", systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            // Generation parameters
            GenerationSettingsView(params: $viewModel.generationParams)
                .frame(maxWidth: 500)
                .onChange(of: viewModel.generationParams) { _, _ in
                    Task { @MainActor in viewModel.saveConfiguration() }
                }
        }
        .alert("New Preset", isPresented: $viewModel.showingNewPresetDialog) {
            TextField("Preset name", text: $viewModel.newPresetName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { viewModel.createPreset() }
        } message: {
            Text("Create a new preset from the current generation parameters.")
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
                    Task { @MainActor in viewModel.saveConfiguration() }
                }

            if viewModel.experimentalFeatures {
                VStack(alignment: .leading, spacing: 16) {
                    // Group Chats
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Group Chats", isOn: $viewModel.groupChatsEnabled)
                            .onChange(of: viewModel.groupChatsEnabled) { _, _ in
                                Task { @MainActor in viewModel.saveConfiguration() }
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
                                Task { @MainActor in viewModel.saveConfiguration() }
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

                    Divider()

                    // Regex Scripts
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Regex Scripts", isOn: $viewModel.regexScriptsEnabled)
                            .onChange(of: viewModel.regexScriptsEnabled) { _, _ in
                                Task { @MainActor in viewModel.saveConfiguration() }
                            }
                        Text("Apply regex find-and-replace rules to input or output text. Useful for formatting, censoring, or transforming messages.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        if viewModel.regexScriptsEnabled {
                            regexRulesEditor
                                .padding(.leading, 20)
                                .padding(.top, 4)
                        }
                    }

                    Divider()

                    // Chat Branching
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Chat Branching", isOn: $viewModel.chatBranchingEnabled)
                            .onChange(of: viewModel.chatBranchingEnabled) { _, _ in
                                Task { @MainActor in viewModel.saveConfiguration() }
                            }
                        Text("Fork conversations at any point to explore different directions. Branches are accessible via the context menu on each message.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    Divider()

                    // Message Drag Reorder
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Message Drag Reorder", isOn: $viewModel.messageDragReorderEnabled)
                            .onChange(of: viewModel.messageDragReorderEnabled) { _, _ in
                                Task { @MainActor in viewModel.saveConfiguration() }
                            }
                        Text("Drag and drop messages to reorder them within a conversation.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    Divider()

                    // Keyboard Message Navigation
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Keyboard Message Navigation", isOn: $viewModel.keyboardMessageNavEnabled)
                            .onChange(of: viewModel.keyboardMessageNavEnabled) { _, _ in
                                Task { @MainActor in viewModel.saveConfiguration() }
                            }
                        Text("Use arrow keys to navigate between messages and quickly select them for editing or other actions.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Regex Rules Editor

    private var regexRulesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.regexRules.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle("", isOn: $viewModel.regexRules[idx].enabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        TextField("Rule name", text: $viewModel.regexRules[idx].name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 150)
                        Picker("", selection: $viewModel.regexRules[idx].appliesTo) {
                            Text("Input").tag(RegexRule.RuleTarget.input)
                            Text("Output").tag(RegexRule.RuleTarget.output)
                            Text("Both").tag(RegexRule.RuleTarget.both)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Spacer()
                        Button(action: {
                            viewModel.regexRules.remove(at: idx)
                            viewModel.saveConfiguration()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    HStack(spacing: 4) {
                        TextField("Pattern (regex)", text: $viewModel.regexRules[idx].pattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        TextField("Replacement", text: $viewModel.regexRules[idx].replacement)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
            }

            Button(action: {
                viewModel.regexRules.append(RegexRule(order: viewModel.regexRules.count))
                viewModel.saveConfiguration()
            }) {
                Label("Add Rule", systemImage: "plus")
                    .font(.system(size: 12))
            }
            .controlSize(.small)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        DataImportExportView(viewModel: viewModel, personaVM: personaVM)
    }

    // MARK: - Reset

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Reset")
                .font(.title2.bold())

            Text("Reset application data. These actions cannot be undone.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                resetRow(
                    title: "Clear All Characters",
                    description: "Remove all characters and their chat histories.",
                    action: { viewModel.showingResetCharactersConfirmation = true }
                )

                resetRow(
                    title: "Clear All Personas",
                    description: "Reset personas to the default \"User\" persona.",
                    action: { viewModel.showingResetPersonasConfirmation = true }
                )

                resetRow(
                    title: "Clear All World Lore",
                    description: "Remove all world lore books and entries.",
                    action: { viewModel.showingResetWorldLoreConfirmation = true }
                )

                resetRow(
                    title: "Clear All Presets",
                    description: "Remove all custom presets and restore the Default preset.",
                    action: { viewModel.showingResetPresetsConfirmation = true }
                )

                Divider()

                resetRow(
                    title: "Reset Everything",
                    description: "Reset the entire application to its default state. All data will be deleted.",
                    isDestructive: true,
                    action: { viewModel.showingResetAllConfirmation = true }
                )
            }
        }
        .alert("Clear All Characters?", isPresented: $viewModel.showingResetCharactersConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { viewModel.resetCharacters() }
        } message: {
            Text("This will permanently delete all characters and their chat histories.")
        }
        .alert("Clear All Personas?", isPresented: $viewModel.showingResetPersonasConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { viewModel.resetPersonas() }
        } message: {
            Text("This will remove all personas and reset to the default \"User\" persona.")
        }
        .alert("Clear All World Lore?", isPresented: $viewModel.showingResetWorldLoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { viewModel.resetWorldLore() }
        } message: {
            Text("This will permanently delete all world lore books.")
        }
        .alert("Clear All Presets?", isPresented: $viewModel.showingResetPresetsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { viewModel.resetPresets() }
        } message: {
            Text("This will remove all custom presets and restore the Default preset.")
        }
        .sheet(isPresented: $viewModel.showingResetAllConfirmation) {
            ResetConfirmationView(
                onConfirm: {
                    viewModel.showingResetAllConfirmation = false
                    viewModel.resetAll()
                },
                onCancel: {
                    viewModel.showingResetAllConfirmation = false
                }
            )
        }
    }

    private func resetRow(title: String, description: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(isDestructive ? "Reset All" : "Clear", role: .destructive, action: action)
                .controlSize(.small)
        }
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// View for importing/exporting data
struct DataImportExportView: View {
    @Bindable var viewModel: SettingsViewModel
    let personaVM: PersonaViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Data Import / Export")
                .font(.title2.bold())

            Text("To import or export individual items, use the Characters, World Lore, Personas, and Chat Presets views. Use this section for bulk operations.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            // Bulk import from directory
            Text("Bulk Import from Directory")
                .font(.headline)

            Text("Point to a SillyTavern installation or any directory containing characters, chats, worlds, and presets to import everything at once.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Root Directory")
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
                        panel.message = "Select the root directory to import from"
                        panel.prompt = "Select"
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.sillyTavernPath = url.path
                        }
                    }
                    .controlSize(.small)
                }

                if !viewModel.sillyTavernPath.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 8) {
                        Button("Import All Data") {
                            viewModel.importFromPath()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isImporting)

                        if viewModel.isImporting {
                            ProgressView()
                                .controlSize(.small)
                            Text("Importing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
            }

            Divider()

            // Export
            Text("Export")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Export All Data") {
                    viewModel.exportAllData()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isExporting)

                if viewModel.isExporting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Exporting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// Confirmation sheet requiring the user to type "I understand" to reset
struct ResetConfirmationView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var confirmationText = ""

    private var isConfirmed: Bool {
        confirmationText.trimmingCharacters(in: .whitespaces).lowercased() == "i understand"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text("Reset Everything")
                .font(.title2.bold())

            Text("This will permanently delete ALL data including characters, chats, personas, world lore, presets, and settings. This action cannot be reversed.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            VStack(alignment: .leading, spacing: 6) {
                Text("Type \"I understand\" to confirm:")
                    .font(.system(size: 12, weight: .medium))
                TextField("", text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape)

                Button("Reset All", role: .destructive, action: onConfirm)
                    .disabled(!isConfirmed)
                    .keyboardShortcut(.return)
            }
        }
        .padding(30)
        .frame(width: 420)
    }
}
