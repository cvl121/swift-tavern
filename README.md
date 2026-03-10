# SwiftTavern

A native macOS app for AI character chat, built with Swift and SwiftUI.

## Why SwiftTavern?

Existing tools like SillyTavern require you to install Node.js, clone a repository, run a local server, and then access everything through a web browser. That's a lot of setup just to have a conversation, and the experience never quite feels like a real Mac app.

SwiftTavern was built to change that. The goal is simple: a fast, smooth, native macOS experience that you can download and start using right away -- no terminal commands, no servers, no browser tabs. Just a regular Mac app that feels at home on your desktop.

## Features

- **Native macOS app** -- built with SwiftUI for a fast, responsive experience that fits right in with the rest of your Mac
- **Multiple AI providers** -- connect to OpenRouter, OpenAI, Claude, Gemini, NovelAI, or run models locally with Ollama
- **Bring your own API key** -- your keys are stored locally in the app's settings file, never sent anywhere except to your chosen provider
- **TavernCardV2 compatible** -- import and export character cards (PNG or JSON) that work with the wider Tavern ecosystem
- **Streaming responses** -- see responses appear in real time as they're generated
- **Swipes** -- generate alternative responses and swipe between them
- **Group chats** -- chat with multiple characters at once, with different turn-taking strategies (natural, round robin, random, manual)
- **World Info & Character Books** -- add lore and context that gets injected into conversations based on keywords, with per-character and global world lore assignment
- **Personas** -- create and switch between different user identities with custom names, descriptions, and avatars
- **Chat history** -- all conversations are saved automatically and searchable, with configurable display limits for long chats
- **Chat styling** -- customize colors for dialogue, actions, and narrative text with labeled live previews
- **Chat presets** -- save and switch between different generation parameter configurations
- **Undo support** -- undo message edits and deletions with Cmd+Z (up to 10 steps)
- **Drag-and-drop import** -- drag PNG or JSON character files directly onto the sidebar to import
- **SillyTavern import** -- bring over your existing characters, chats, world info, presets, and personas from SillyTavern
- **Light & dark mode** -- adapts to your system appearance with theme-aware chat colors
- **Resizable sidebar** -- drag to resize, and the app remembers your preference across sessions

## Requirements

- macOS 14 (Sonoma) or later
- An API key from a supported provider (or Ollama running locally)

## Getting Started

1. **Build and run** the app (requires Swift 5.9+):
   ```bash
   swift build
   .build/debug/SwiftTavern
   ```

2. **Add an API key** -- go to Settings and enter your key for your preferred provider. OpenRouter is recommended as a starting point since it gives you access to many models through a single key.

3. **Import or create a character** -- import a TavernCardV2 PNG/JSON file, drag a character file onto the sidebar, or create a new character from scratch.

4. **Start chatting** -- select a character from the sidebar and send a message.

## Supported Providers

| Provider | What you need |
|----------|--------------|
| [OpenRouter](https://openrouter.ai) | API key (access to many models) |
| [OpenAI](https://platform.openai.com) | API key |
| [Anthropic Claude](https://console.anthropic.com) | API key |
| [Google Gemini](https://aistudio.google.com) | API key |
| [NovelAI](https://novelai.net) | API key |
| [Ollama](https://ollama.ai) | Local install (no API key needed) |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd + N | New chat |
| Cmd + Shift + N | New character |
| Cmd + F | Search in chat |
| Cmd + R | Regenerate last response |
| Cmd + Z | Undo last message edit/delete |
| Cmd + , | Settings |
| Escape | Stop generating / cancel edit |

## Data Storage

All your data is stored locally on your Mac:

- **Characters, chats, settings, and API keys** are saved in `~/Library/Application Support/SwiftTavern/`
- Nothing is sent to any server except your chosen AI provider when you send a message

## Building from Source

```bash
# Clone the repository
git clone https://github.com/user/swift-tavern.git
cd swift-tavern

# Build
swift build

# Run tests
swift test

# Release build
swift build -c release
```

## License

This project is open source. See the repository for license details.
