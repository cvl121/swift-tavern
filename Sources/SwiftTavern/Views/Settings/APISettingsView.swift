import SwiftUI

/// Text API configuration settings — for chat/conversation LLM providers
struct APISettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Text-capable API providers (excludes image-only providers)
    private var textProviders: [APIType] {
        APIType.allCases.filter { $0 != .novelai }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Text API")
                .font(.title2.bold())

            Text("Choose the AI provider for chat conversations and text generation.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            // API Provider picker
            Picker("API Provider", selection: $viewModel.selectedAPI) {
                ForEach(textProviders) { api in
                    Text(api.displayName).tag(api)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedAPI) { _, newValue in
                viewModel.switchAPI(newValue)
            }

            // API Key
            if viewModel.selectedAPI.requiresAPIKey {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        if viewModel.showAPIKey {
                            TextField("Enter API key", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Enter API key", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { viewModel.showAPIKey.toggle() }) {
                            Image(systemName: viewModel.showAPIKey ? "eye.slash" : "eye")
                        }

                        Button("Save Key") {
                            viewModel.saveAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            // Model selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Picker("Model", selection: $viewModel.model) {
                        ForEach(viewModel.selectedAPI.defaultModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()

                    TextField("Or type model name", text: $viewModel.model)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
            }

            // Base URL (for custom endpoints)
            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL (optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField(viewModel.selectedAPI == .ollama ? "http://localhost:11434" : "Default",
                         text: $viewModel.baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
}
