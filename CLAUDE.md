# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
swift build

# Release build
swift build -c release

# Run all tests (107 tests)
swift test

# Run a single test
swift test --filter SwiftTavernTests.CharacterTests/testCharacterDecoding

# Clean build (required after directory renames)
rm -rf .build && swift build
```

All commands run from the project root where `Package.swift` lives.

## Architecture

**MVVM + Service layer** using Swift's `@Observable` macro (macOS 14+, SPM, single dependency: Yams).

### Core Flow

`SwiftTavernApp` → `AppState` (central observable container) → ViewModels → Services

- **AppState** (`App/AppState.swift`): Owns all storage services and shared state (characters, chats, settings, navigation). Initialized at app launch, passed to views.
- **ViewModels** (`ViewModels/`): `@Observable` classes coordinating business logic. `ChatViewModel` handles message generation, streaming, swipes. `SettingsViewModel` manages API config and Keychain access.
- **Services** (`Services/`): Stateless helpers for storage, LLM calls, PNG parsing, prompt building.

### LLM Provider System

Protocol-based with factory pattern:
- `LLMService` protocol defines `sendMessage()` (streaming) and `sendMessageComplete()` (non-streaming)
- `LLMServiceFactory.create(for:)` returns the appropriate implementation
- Five providers: OpenRouter (default), OpenAI, Claude, Gemini, Ollama
- `SSEParser` handles Server-Sent Events for streaming responses
- API keys stored in macOS Keychain via `SecretsStorageService` (service: `com.swifttavern.macos`)

### Character Card System (TavernCardV2)

Characters are PNG files with JSON embedded in tEXt chunks (key: `"chara"`, base64-encoded):
- `PNGChunkReader` / `PNGChunkWriter` handle raw PNG chunk I/O
- `CharacterCardParser` wraps parse/embed operations
- `CharacterStorageService` manages character file CRUD

### Chat Storage

JSONL format (first line = metadata, subsequent lines = messages). Files stored in `chats/{CharacterName}/`.
- `ChatStorageService` is thread-safe via `DispatchQueue`
- Messages support swipes (alternative responses stored in array)

### Prompt Assembly

`PromptBuilder.buildMessages()` assembles the full LLM context:
system prompt → character description/personality/scenario → persona → character book entries → world info → few-shot examples → chat history → post-history instructions

Template variables `{{char}}` and `{{user}}` are replaced via `String.replacingTemplateVars()`.

## Key Conventions

- Use `@Observable` macro for state, `@Bindable` for `$` bindings
- Use `CharacterGroup` (not `Group`) to avoid SwiftUI namespace conflict
- Use `.isoLatin1` (not `.latin1`) for string encoding
- File naming: characters are `{sanitizedName}.png`, chats are `{CharName} - {timestamp}-{UUID}.jsonl`
- Data directory: `~/Library/Application Support/SwiftTavern/`
- Settings auto-save with 500ms debounce
