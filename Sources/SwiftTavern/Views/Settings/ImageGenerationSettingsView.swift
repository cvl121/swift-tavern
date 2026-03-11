import SwiftUI

/// Settings view for image generation configuration
struct ImageGenerationSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Image Generation")
                .font(.title2.bold())

            Text("Generate images during conversations using AI image models. The main LLM summarizes the current scene into a visual prompt, then an image generation API produces the image.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            // Master toggle
            Toggle("Enable Image Generation", isOn: $viewModel.imageGenSettings.enabled)
                .onChange(of: viewModel.imageGenSettings.enabled) { _, _ in
                    viewModel.saveConfiguration()
                }

            if viewModel.imageGenSettings.enabled {
                providerSection
                Divider()
                imageOptionsSection
                Divider()
                triggerSection
                Divider()
                promptSection
            }
        }
    }

    // MARK: - Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider")
                .font(.headline)

            HStack {
                Picker("Provider", selection: $viewModel.imageGenSettings.provider) {
                    ForEach(ImageGenProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            .onChange(of: viewModel.imageGenSettings.provider) { _, newProvider in
                viewModel.switchImageGenProvider(newProvider)
            }

            // API Key
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Group {
                        if viewModel.showImageGenAPIKey {
                            TextField("Enter API key", text: $viewModel.imageGenAPIKey)
                        } else {
                            SecureField("Enter API key", text: $viewModel.imageGenAPIKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                    Button(action: { viewModel.showImageGenAPIKey.toggle() }) {
                        Image(systemName: viewModel.showImageGenAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    Button("Save Key") {
                        viewModel.saveConfiguration()
                    }
                    .controlSize(.small)
                }
            }

            // Model
            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Picker("Model", selection: $viewModel.imageGenSettings.model) {
                        ForEach(viewModel.imageGenSettings.provider.defaultModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    TextField("or enter model name", text: $viewModel.imageGenSettings.model)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
            }

            // Base URL (for custom)
            if viewModel.imageGenSettings.provider == .custom {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("https://api.example.com", text: Binding(
                        get: { viewModel.imageGenSettings.baseURL ?? "" },
                        set: { viewModel.imageGenSettings.baseURL = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)
                }
            }

            // Test button
            HStack(spacing: 8) {
                Button("Test Image Generation") {
                    viewModel.testImageGenConnection()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)

                if let result = viewModel.imageGenTestResult {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundColor(result.hasPrefix("Success") ? .green : .secondary)
                }
            }
        }
    }

    // MARK: - Image Options

    private var imageOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Options")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("Size", selection: $viewModel.imageGenSettings.imageSize) {
                        ForEach(ImageSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("Quality", selection: $viewModel.imageGenSettings.quality) {
                        ForEach(ImageQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .onChange(of: viewModel.imageGenSettings.imageSize) { _, _ in
                viewModel.saveConfiguration()
            }
            .onChange(of: viewModel.imageGenSettings.quality) { _, _ in
                viewModel.saveConfiguration()
            }
        }
    }

    // MARK: - Trigger Mode

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trigger Mode")
                .font(.headline)

            Picker("How images are triggered", selection: $viewModel.imageGenSettings.triggerMode) {
                ForEach(ImageTriggerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            .fixedSize()
            .onChange(of: viewModel.imageGenSettings.triggerMode) { _, _ in
                viewModel.saveConfiguration()
            }

            switch viewModel.imageGenSettings.triggerMode {
            case .manual:
                Text("Images are only generated when you click the camera button in the chat toolbar.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

            case .everyNMessages:
                HStack {
                    Text("Generate image every")
                        .font(.system(size: 12))
                    Stepper(value: $viewModel.imageGenSettings.messageInterval, in: 1...50) {
                        Text("\(viewModel.imageGenSettings.messageInterval)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .fixedSize()
                    Text("messages")
                        .font(.system(size: 12))
                }
                .onChange(of: viewModel.imageGenSettings.messageInterval) { _, _ in
                    viewModel.saveConfiguration()
                }

            case .injectedPrompt:
                Text("The LLM will decide when to generate images by including a [GENERATE_IMAGE] tag in its responses. You can customize the injection prompt below.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Prompt Templates

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt Templates")
                .font(.headline)

            if viewModel.imageGenSettings.triggerMode == .injectedPrompt {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLM Injection Prompt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Injected into the LLM context to tell it when to request images.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextEditor(text: $viewModel.imageGenSettings.injectionPrompt)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                    Button("Reset to Default") {
                        viewModel.imageGenSettings.injectionPrompt = ImageGenerationSettings.defaultInjectionPrompt
                        viewModel.saveConfiguration()
                    }
                    .controlSize(.mini)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Scene-to-Prompt Template")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Sent to the main LLM to translate the current scene into an image prompt. Use {{char_description}} for character info.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.imageGenSettings.scenePromptTemplate)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                Button("Reset to Default") {
                    viewModel.imageGenSettings.scenePromptTemplate = ImageGenerationSettings.defaultScenePromptTemplate
                    viewModel.saveConfiguration()
                }
                .controlSize(.mini)
            }

            Toggle("Use main chat LLM for scene summarization", isOn: $viewModel.imageGenSettings.useMainAPIForSceneSummary)
                .font(.system(size: 12))
                .onChange(of: viewModel.imageGenSettings.useMainAPIForSceneSummary) { _, _ in
                    viewModel.saveConfiguration()
                }
        }
    }
}
