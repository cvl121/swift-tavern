import SwiftUI

/// First-launch onboarding and tutorial view
struct OnboardingView: View {
    var onDismiss: () -> Void
    var onSetUpAPI: (() -> Void)?

    @State private var currentPage = 0
    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                featuresPage.tag(1)
                tutorialPage.tag(2)
                getStartedPage.tag(3)
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation footer
            HStack {
                Button("Skip") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 13))

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { page in
                        Circle()
                            .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: page == currentPage ? 8 : 6, height: page == currentPage ? 8 : 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation(.spring(response: 0.35)) { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button("Get Started") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 560, idealWidth: 640, maxWidth: 720, minHeight: 520, idealHeight: 620, maxHeight: 800)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 12)

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

                Divider().padding(.horizontal, 60)

                VStack(spacing: 6) {
                    Text("SwiftTavern lets you chat with AI characters using your own API keys.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Your data stays on your Mac. Keys are only sent to your chosen AI provider.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .padding(.bottom, 8)

                // Highlights
                HStack(spacing: 24) {
                    highlightBadge(icon: "bolt.fill", label: "Fast & Native", color: .orange)
                    highlightBadge(icon: "lock.fill", label: "Private", color: .green)
                    highlightBadge(icon: "arrow.triangle.2.circlepath", label: "SillyTavern\nCompatible", color: .purple)
                    highlightBadge(icon: "network", label: "6 AI\nProviders", color: .blue)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Text("What You Can Do")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 14) {
                    featureRow(
                        icon: "bubble.left.and.text.bubble.right.fill",
                        color: .green,
                        title: "Rich Chat Experience",
                        description: "Stream responses in real time, swipe between alternative replies, search conversations, bookmark messages, and fork chats."
                    )

                    featureRow(
                        icon: "person.text.rectangle.fill",
                        color: .blue,
                        title: "TavernCardV2 Characters",
                        description: "Import character cards as PNG or JSON, create your own, or drag and drop files onto the sidebar."
                    )

                    featureRow(
                        icon: "network",
                        color: .orange,
                        title: "Multiple AI Providers",
                        description: "OpenRouter, OpenAI, Claude, Gemini, NovelAI, or local models via Ollama. Switch providers anytime."
                    )

                    featureRow(
                        icon: "photo.fill",
                        color: .pink,
                        title: "Image Generation",
                        description: "Generate scene illustrations with DALL-E, Stability AI, NovelAI Diffusion, or OpenRouter image models. Use character avatars as reference images."
                    )

                    featureRow(
                        icon: "globe",
                        color: .purple,
                        title: "World Lore & Character Books",
                        description: "Keyword-triggered lore entries automatically woven into conversations. Assign lore globally or per character."
                    )

                    featureRow(
                        icon: "person.2.fill",
                        color: .teal,
                        title: "Personas & Group Chats",
                        description: "Multiple user identities with custom avatars. Chat with several characters at once."
                    )

                    featureRow(
                        icon: "paintpalette.fill",
                        color: .indigo,
                        title: "Customizable Styling",
                        description: "Color-code dialogue, actions, and narrative text. Set styles globally or per conversation."
                    )
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Page 3: Tutorial

    private var tutorialPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Text("How to Use SwiftTavern")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 16) {
                    tutorialStep(
                        number: 1,
                        title: "Set up your API key",
                        description: "Go to **Settings > API Provider** in the bottom-left menu. Select a provider (we recommend OpenRouter), paste your API key, and pick a model.",
                        icon: "key.fill",
                        color: .orange
                    )

                    tutorialStep(
                        number: 2,
                        title: "Choose or import a character",
                        description: "Click **Characters** in the bottom-left menu to browse, create, or import characters. Drag a PNG or JSON character card onto the sidebar to import instantly.",
                        icon: "person.crop.circle.badge.plus",
                        color: .blue
                    )

                    tutorialStep(
                        number: 3,
                        title: "Start chatting",
                        description: "Click a character in the sidebar to open their conversation. Type your message and press **Enter** to send. The AI response streams in real time.",
                        icon: "text.bubble.fill",
                        color: .green
                    )

                    tutorialStep(
                        number: 4,
                        title: "Explore more features",
                        description: "Right-click messages for options like edit, regenerate, or delete. Use the **swipe arrows** on AI messages to get alternative responses. Click the **camera icon** to generate images.",
                        icon: "sparkles",
                        color: .purple
                    )

                    tutorialStep(
                        number: 5,
                        title: "Customize your experience",
                        description: "Set up **Personas** for different user identities. Add **World Lore** for rich context. Adjust **Chat Style** colors and font size in Settings > General.",
                        icon: "slider.horizontal.3",
                        color: .pink
                    )
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Page 4: Get Started

    private var getStartedPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 24)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("You're All Set!")
                    .font(.title.bold())

                Text("Here's a quick reference for keyboard shortcuts:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                // Keyboard shortcuts
                VStack(alignment: .leading, spacing: 8) {
                    shortcutRow(keys: "Cmd + N", action: "New conversation")
                    shortcutRow(keys: "Cmd + Shift + N", action: "New character")
                    shortcutRow(keys: "Cmd + F", action: "Search messages")
                    shortcutRow(keys: "Cmd + Shift + F", action: "Global search")
                    shortcutRow(keys: "Cmd + R", action: "Regenerate response")
                    shortcutRow(keys: "Cmd + ,", action: "Open settings")
                    shortcutRow(keys: "Enter", action: "Send message")
                    shortcutRow(keys: "Shift + Enter", action: "New line")
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

                Divider().padding(.horizontal, 60)

                VStack(spacing: 12) {
                    Button(action: {
                        onSetUpAPI?()
                        onDismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                            Text("Set Up API Key Now")
                        }
                        .font(.headline)
                        .frame(maxWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("You can also do this later in Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Subviews

    private func highlightBadge(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 90)
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 30)

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

    private func tutorialStep(number: Int, title: String, description: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(.init(description))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func shortcutRow(keys: String, action: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 160, alignment: .leading)
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}
