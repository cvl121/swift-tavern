import SwiftUI

/// First-launch onboarding view explaining the app
struct OnboardingView: View {
    var onDismiss: () -> Void

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
                        icon: "person.text.rectangle.fill",
                        color: .blue,
                        title: "Character Cards",
                        description: "Create, import, and manage AI characters using the TavernCardV2 format. Import characters from SillyTavern as PNG or JSON files."
                    )

                    featureRow(
                        icon: "bubble.left.and.text.bubble.right.fill",
                        color: .green,
                        title: "Chat Interface",
                        description: "Have conversations with your characters. Edit, delete, or regenerate messages. Browse alternative responses with swipe navigation."
                    )

                    featureRow(
                        icon: "network",
                        color: .orange,
                        title: "Multiple AI Providers",
                        description: "Connect to OpenRouter, OpenAI, Claude (Anthropic), Google Gemini, or Ollama for local models. Switch between providers at any time."
                    )

                    featureRow(
                        icon: "globe",
                        color: .purple,
                        title: "World Lore",
                        description: "Create world info books with keyword-triggered entries that are automatically injected into conversations for richer context."
                    )

                    featureRow(
                        icon: "person.circle.fill",
                        color: .pink,
                        title: "Personas",
                        description: "Define multiple user personas with custom descriptions that shape how characters perceive and interact with you."
                    )

                    featureRow(
                        icon: "square.and.arrow.down.on.square.fill",
                        color: .teal,
                        title: "SillyTavern Import",
                        description: "Import your entire SillyTavern installation including characters, chats, world lore, and presets via Settings > Data."
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

                    Text("SwiftTavern requires your own API key to chat with AI characters. We recommend **OpenRouter** as it gives you access to models from OpenAI, Anthropic, Google, Meta, and more with a single key.\n\nYour keys are stored securely in the macOS Keychain and never saved in plain text. You may see a one-time Keychain access prompt \u{2014} this is macOS verifying your permission.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }

                // Getting started
                VStack(spacing: 8) {
                    Text("Getting Started")
                        .font(.headline)

                    Text("Head to **Settings > API Provider**, select your provider (OpenRouter recommended), enter your API key, and choose a model. Then pick a character from the sidebar to start chatting.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }

                Button(action: onDismiss) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 600, height: 650)
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
