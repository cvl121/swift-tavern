# SwiftTavern

A native macOS app for AI character chat, built with Swift and SwiftUI.

## Why SwiftTavern?

Existing tools like SillyTavern require you to install Node.js, clone a repository, run a local server, and then access everything through a web browser. That's a lot of setup just to have a conversation, and the experience never quite feels like a real Mac app.

SwiftTavern was built to change that. The goal is simple: a fast, smooth, native macOS experience that you can download and start using right away -- no terminal commands, no servers, no browser tabs. Just a regular Mac app that feels at home on your desktop.

## Features

### Chat & Conversation
- **Streaming responses** -- see responses appear in real time as they're generated
- **Swipes** -- generate alternative responses and swipe between them, including alternate greetings
- **Chat history** -- all conversations are saved automatically with per-character history, switchable from the conversation toolbar
- **Message editing** -- edit, delete, or regenerate any message; undo with Cmd+Z (up to 10 steps)
- **Unified search** -- search within the current conversation or across all chats for a character from a single search bar
- **Bookmarks & forks** -- bookmark important messages and fork conversations from any point
- **Group chats** -- chat with multiple characters at once using different turn-taking strategies (natural, round robin, random, manual)

### Characters & World Building
- **TavernCardV2 compatible** -- import and export character cards (PNG or JSON) that work with the wider Tavern ecosystem
- **Drag-and-drop import** -- drag PNG or JSON character files directly onto the sidebar to import
- **Character books** -- per-character lore entries with keyword triggers, position control, and priority
- **World Info** -- standalone world lore books with keyword-triggered entries, assignable globally or per-character
- **Personas** -- create and switch between user identities with custom names, descriptions, and avatars

### AI Providers
- **Six providers** -- OpenRouter, OpenAI, Claude (Anthropic), Google Gemini, NovelAI, and Ollama (local)
- **Bring your own API key** -- keys are stored locally and never sent anywhere except to your chosen provider
- **Live model lists** -- OpenRouter models fetched and searchable in real time
- **Connection testing** -- verify your API key and endpoint before chatting
- **Configurable generation** -- temperature, top-p, top-k, penalties, max tokens, stop sequences, and streaming toggle

### Customization
- **Chat text styling** -- customize colors for dialogue (quoted text), actions (italic/emote), and narrative text with live preview
- **Per-conversation styles** -- override global chat styling for individual conversations
- **Markdown support** -- headers, bold, italic, blockquotes, lists, horizontal rules, and inline code in chat messages
- **Italic speech** -- `*"quoted text in asterisks"*` renders as italic with dialogue color, matching SillyTavern behavior
- **App-wide UI scale** -- adjust the overall text size of the application interface
- **Light & dark mode** -- adapts to your system appearance with theme-aware chat colors
- **Resizable sidebar** -- drag to resize, persisted across sessions
- **Persistent input height** -- chat input field remembers its size across navigation

### Data & Import
- **SillyTavern import** -- bring over your existing characters, chats, world info, presets, and personas
- **Export options** -- export chats as JSONL or Markdown, export characters as PNG with embedded card data
- **Local storage** -- all data stored in `~/Library/Application Support/SwiftTavern/`, nothing in the cloud

## Requirements

- macOS 14 (Sonoma) or later
- An API key from a supported provider (or Ollama running locally)

## Getting Started

1. **Download the DMG** and drag SwiftTavern to your Applications folder, or build from source.

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
| Cmd + Shift + H | Chat history |
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
