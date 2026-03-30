![](https://github.com/cvl121/swift-tavern/blob/main/Screenshot%202026-03-30%20at%2015.18.55.png)

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
- **Chat presets** -- save and load named generation parameter presets; import/export SillyTavern preset format
- **Reminder prompt** -- optional instruction reminder injected near the end of the conversation to reinforce style, formatting, or tense that models tend to forget in long chats

### Characters & World Building
- **TavernCardV2 compatible** -- import and export character cards (PNG or JSON) that work with the wider Tavern ecosystem
- **Drag-and-drop import** -- drag PNG or JSON character files directly onto the sidebar to import
- **Character books** -- per-character lore entries with keyword triggers, position control, and priority
- **World Info** -- standalone world lore books with keyword-triggered entries, assignable globally or per-character
- **Personas** -- create and switch between user identities with custom names, descriptions, and avatars
- **Per-character personas** -- assign a specific persona to individual characters so the right identity is used automatically

### AI Providers

SwiftTavern is designed primarily around **OpenRouter**, which gives you access to hundreds of models through a single API key and is the recommended starting point. That said, the app supports several other text-based providers if you prefer to use them directly:

| Provider | What you need | Notes |
|----------|--------------|-------|
| [OpenRouter](https://openrouter.ai) | API key | **Recommended.** Access to many models, live searchable model list, single key. |
| [OpenAI](https://platform.openai.com) | API key | Direct access to GPT models. |
| [Anthropic Claude](https://console.anthropic.com) | API key | Direct access to Claude models. |
| [Google Gemini](https://aistudio.google.com) | API key | Direct access to Gemini models. |
| [NovelAI](https://novelai.net) | API key | Specialized for creative/fiction writing. |
| [Ollama](https://ollama.ai) | Local install | Run models locally, no API key needed. |

### Customization
- **Chat text styling** -- customize colors for dialogue (quoted text), actions (italic/emote), and narrative text with live preview
- **Per-conversation styles** -- override global chat styling for individual conversations
- **Markdown support** -- headers, bold, italic, blockquotes, lists, horizontal rules, and inline code in chat messages
- **Italic speech** -- `*"quoted text in asterisks"*` renders as italic with dialogue color, matching SillyTavern behavior
- **App-wide UI scale** -- adjust the overall text size of the application interface
- **Light & dark mode** -- adapts to your system appearance with theme-aware chat colors
- **Resizable sidebar** -- drag to resize, persisted across sessions
- **Persistent input height** -- chat input field remembers its size across navigation
- **Configurable generation** -- temperature, top-p, top-k, penalties, max tokens, stop sequences, streaming toggle, and advanced sampling (minP, topA, typicalP, TFS, Mirostat, dynamic temperature)

### Data & Import
- **SillyTavern import** -- bring over your existing characters, chats, world info, presets, and personas
- **Export options** -- export chats as JSONL or Markdown, export characters as PNG with embedded card data
- **Local storage** -- all data stored in `~/Library/Application Support/SwiftTavern/`, nothing in the cloud
- **Pinned characters** -- pin frequently-used characters to the top of the conversation list

### Developer Tools
- **Developer mode** -- enable a live log viewer for API requests, responses, and errors to help debug provider issues

## Experimental Features

The following features are available behind the **Experimental Features** toggle in Settings. They are still under active development and may not work as expected:

| Feature | Description |
|---------|-------------|
| **Group Chats** | Chat with multiple characters at once using different turn-taking strategies (natural, round robin, random, manual). Groups appear in the sidebar conversations list. |
| **Image Generation** | Generate images within conversations using AI image models (DALL-E, Stability AI, OpenRouter, NovelAI). Two-step pipeline: LLM generates a visual prompt from chat context, then an image service creates the image. Supports manual, automatic (every N messages), and LLM-triggered modes. |
| **Regex Scripts** | Apply regex find-and-replace rules to input or output text. Useful for formatting, censoring, or transforming messages. Includes a built-in rule editor with per-rule enable/disable. |
| **Chat Branching** | Fork conversations at any point to explore different directions. Branches are accessible via the context menu on each message. |
| **Message Drag Reorder** | Drag and drop messages to reorder them within a conversation. |
| **Keyboard Message Navigation** | Use arrow keys to navigate between messages and quickly select them for editing or other actions. |

## Requirements

- macOS 14 (Sonoma) or later
- An API key from a supported provider (or Ollama running locally)

## Getting Started

1. **Download the DMG** and drag SwiftTavern to your Applications folder, or build from source.

2. **Add an API key** -- go to Settings and enter your key for your preferred provider. OpenRouter is recommended as a starting point since it gives you access to many models through a single key.

3. **Import or create a character** -- import a TavernCardV2 PNG/JSON file, drag a character file onto the sidebar, or create a new character from scratch.

4. **Start chatting** -- select a character from the sidebar and send a message.

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
