import SwiftUI

/// First-launch onboarding view explaining the app
struct OnboardingView: View {
    var onDismiss: () -> Void
    var onSetUpAPI: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("Welcome to SwiftTavern")
                        .font(.largeTitle.bold())

                    Text("A native macOS client for AI character conversations")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 40)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(
                        icon: "bubble.left.and.text.bubble.right.fill",
                        color: .green,
                        title: "Rich Chat Experience",
                        description: "Stream responses in real time, swipe between alternative replies, search across conversations, bookmark messages, and fork chats from any point."
                    )

                    featureRow(
                        icon: "person.text.rectangle.fill",
                        color: .blue,
                        title: "TavernCardV2 Characters",
                        description: "Import characters as PNG or JSON, create your own, or drag and drop files onto the sidebar. Fully compatible with the SillyTavern ecosystem."
                    )

                    featureRow(
                        icon: "network",
                        color: .orange,
                        title: "Six AI Providers",
                        description: "Connect to OpenRouter, OpenAI, Claude, Gemini, NovelAI, or run models locally with Ollama. Switch providers and models at any time."
                    )

                    featureRow(
                        icon: "paintpalette.fill",
                        color: .pink,
                        title: "Customizable Styling",
                        description: "Color-code dialogue, actions, and narrative text. Set styles globally or per conversation. Full markdown support including headers, bold, italic, and lists."
                    )

                    featureRow(
                        icon: "globe",
                        color: .purple,
                        title: "World Lore & Character Books",
                        description: "Build rich worlds with keyword-triggered lore entries that are automatically woven into conversations. Assign lore globally or per character."
                    )

                    featureRow(
                        icon: "person.2.fill",
                        color: .teal,
                        title: "Personas & Group Chats",
                        description: "Define multiple user identities with custom descriptions and avatars. Chat with multiple characters at once using different turn-taking strategies."
                    )

                    featureRow(
                        icon: "square.and.arrow.down.on.square.fill",
                        color: .indigo,
                        title: "SillyTavern Import",
                        description: "Bring over your entire SillyTavern setup -- characters, chats, world lore, presets, and personas -- via Settings > Data."
                    )
                }
                .padding(.horizontal, 32)

                Divider()
                    .padding(.horizontal, 40)

                // API key note
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("Bring Your Own API Key")
                            .font(.headline)
                    }

                    Text("SwiftTavern requires your own API key to chat with AI characters. We recommend **OpenRouter** as it gives you access to models from OpenAI, Anthropic, Google, Meta, and more with a single key.\n\nYour keys are stored locally on your Mac and are never sent anywhere except to your chosen AI provider.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }

                // Getting started
                VStack(spacing: 8) {
                    Text("Getting Started")
                        .font(.headline)

                    Text("Head to **Settings > API Provider**, select your provider, enter your API key, and choose a model. Then pick a character from the sidebar to start chatting.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button(action: {
                            onSetUpAPI?()
                            onDismiss()
                        }) {
                            Text("Set Up API Key")
                                .font(.headline)
                                .frame(maxWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    HStack(spacing: 16) {
                        Button(action: onDismiss) {
                            Text("Skip for Now")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 600, height: 700)
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
