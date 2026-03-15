import SwiftUI
import AppKit

/// Sheet for editing an image generation prompt before sending it to the provider
struct ImagePromptEditorView: View {
    @Bindable var chatVM: ChatViewModel
    let appState: AppState

    private var provider: ImageGenProvider {
        appState.settings.imageGenerationSettings.provider
    }

    private var canGenerate: Bool {
        !chatVM.imageEditorPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !chatVM.isGeneratingImage
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Generate Image")
                    .font(.title3.bold())
                Spacer()
                Text(provider.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Provider hint
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 13))
                            .padding(.top, 1)
                        Text(provider.promptHint)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.06))
                    .cornerRadius(6)

                    // Prompt
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextEditor(text: $chatVM.imageEditorPrompt)
                            .font(.system(size: 12, design: provider == .novelai ? .monospaced : .default))
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                    }

                    // Negative prompt (provider-specific)
                    if provider.supportsNegativePrompt {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Negative Prompt")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("Elements to exclude from the generated image.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            TextEditor(text: $chatVM.imageEditorNegativePrompt)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 60)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.separatorColor), lineWidth: 1)
                                )
                            if chatVM.imageEditorNegativePrompt.isEmpty {
                                Text("Leave empty to use default: \(provider.negativePromptHint)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .lineLimit(2)
                            }
                        }
                    }

                    // Reference image toggle (for supported providers)
                    if provider.supportsReferenceImage {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: Binding(
                                get: { appState.settings.imageGenerationSettings.useReferenceImage },
                                set: { appState.settings.imageGenerationSettings.useReferenceImage = $0; appState.saveSettings() }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Character Avatar as Reference")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("The character's avatar image will guide the generated output.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if appState.settings.imageGenerationSettings.useReferenceImage {
                                HStack(spacing: 8) {
                                    Text("Influence Strength")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: Binding(
                                            get: { appState.settings.imageGenerationSettings.referenceImageStrength },
                                            set: { appState.settings.imageGenerationSettings.referenceImageStrength = $0; appState.saveSettings() }
                                        ),
                                        in: 0.1...0.9,
                                        step: 0.05
                                    )
                                    Text(String(format: "%.0f%%", appState.settings.imageGenerationSettings.referenceImageStrength * 100))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }

                                // Preview the reference image
                                if let avatarData = appState.selectedCharacter?.avatarData,
                                   let nsImage = NSImage(data: avatarData) {
                                    HStack(spacing: 8) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 48, height: 48)
                                            .cornerRadius(6)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor), lineWidth: 0.5))
                                        Text("Reference: \(appState.selectedCharacter?.card.data.name ?? "Character") avatar")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }

                    // Error message
                    if let error = chatVM.imageGenerationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button(action: { chatVM.autoGeneratePromptForEditor() }) {
                    HStack(spacing: 4) {
                        if chatVM.isAutoGeneratingPrompt {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text("Auto-generate from scene")
                    }
                }
                .disabled(chatVM.isAutoGeneratingPrompt)
                .controlSize(.small)
                .help("Use the chat LLM to generate a prompt from the current conversation")

                Spacer()

                Button("Cancel") {
                    chatVM.showingImagePromptEditor = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Generate") {
                    chatVM.generateImageWithCustomPrompt()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canGenerate)
            }
            .padding(16)
        }
        .frame(idealWidth: 520, minHeight: 480, idealHeight: 560, maxHeight: 640)
        .frame(width: 520)
    }
}
