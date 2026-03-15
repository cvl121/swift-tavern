# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
swift build

# Release build
swift build -c release

# Run all tests (154 tests)
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

- **AppState** (`App/AppState.swift`): Owns all storage services and shared state (characters, chats, settings, navigation). Initialized at app launch, passed to views. Also provides `imageGenService()`, `imageGenAPIKey()`, and `devLogger`.
- **ViewModels** (`ViewModels/`): `@Observable` classes coordinating business logic. `ChatViewModel` handles message generation, streaming, swipes, and image generation. `SettingsViewModel` manages API config.
- **Services** (`Services/`): Stateless helpers for storage, LLM calls, image generation, PNG parsing, prompt building.

### LLM Provider System

Protocol-based with factory pattern:
- `LLMService` protocol defines `sendMessage()` (streaming) and `sendMessageComplete()` (non-streaming)
- `LLMServiceFactory.create(for:)` returns the appropriate implementation
- Six providers: OpenRouter (default), OpenAI, Claude, Gemini, Ollama, NovelAI
- `SSEParser` handles Server-Sent Events for streaming responses
- API keys stored in `AppSettings.apiKeys` dictionary, persisted to the settings JSON file

### Image Generation System

Two-step pipeline: chat context → LLM generates visual prompt → image generation service creates image.

Protocol-based with factory pattern (mirrors LLM system):
- `ImageGenerationService` protocol defines `generateImage(prompt:negativePrompt:settings:apiKey:)`
- `ImageGenServiceFactory.create(for:)` returns provider-specific implementation
- Four providers: DALL-E (OpenAI), Stability AI, OpenRouter, NovelAI
- `ScenePromptBuilder` uses the main LLM to translate recent chat context into image prompts
- Template variables: `{{char}}`, `{{user}}`, `{{char_description}}`
- Generated images stored in `generated_images/{CharacterName}/`
- Trigger modes: manual, everyNMessages, injectedPrompt (LLM-triggered)
- Shared API key pattern: image providers can reuse text provider keys (e.g., OpenRouter image uses OpenRouter text key)

### Character Card System (TavernCardV2)

Characters are PNG files with JSON embedded in tEXt chunks (key: `"chara"`, base64-encoded):
- `PNGChunkReader` / `PNGChunkWriter` handle raw PNG chunk I/O
- `CharacterCardParser` wraps parse/embed operations
- `CharacterStorageService` manages character file CRUD

### Chat Storage

JSONL format (first line = metadata, subsequent lines = messages). Files stored in `chats/{CharacterName}/`.
- `ChatStorageService` is thread-safe via `DispatchQueue`
- Messages support swipes (alternative responses stored in array)
- Messages may include `imageURL` and `imagePrompt` fields for generated images

### Chat Presets System

Named generation parameter presets:
- `ChatPreset` model: name + `GenerationParameters`
- `PresetStorageService`: CRUD for preset JSON files in `presets/` directory
- Import/export SillyTavern preset format
- Default preset always included
- `AppState` tracks `presets` array and `activePresetName`

### Prompt Assembly

`PromptBuilder.buildMessages()` assembles the full LLM context:
system prompt → character description/personality/scenario → persona → character book entries → world info → few-shot examples → chat history → post-history instructions

Template variables `{{char}}` and `{{user}}` are replaced via `String.replacingTemplateVars()`.

### Developer Logging

`DevLogger` (`Services/DevLogger.swift`): Thread-safe `@Observable` logger for API requests/responses.
- `LogEntry` with timestamp, type (REQ/RES/ERR/INFO), message
- Max 500 entries, thread-safe via MainActor dispatch
- `AppState.devLogger` property, enabled via `developerMode` setting
- Displayed in `DevLogView` (color-coded, auto-scrolling, text-selectable)

## Key Conventions

- Use `@Observable` macro for state, `@Bindable` for `$` bindings
- Use `CharacterGroup` (not `Group`) to avoid SwiftUI namespace conflict
- Use `.isoLatin1` (not `.latin1`) for string encoding
- File naming: characters are `{sanitizedName}.png`, chats are `{CharName} - {timestamp}-{UUID}.jsonl`
- Data directory: `~/Library/Application Support/SwiftTavern/`
- Settings auto-save with 500ms debounce
- All new settings fields use `decodeIfPresent` with sensible defaults for backward compatibility
- Image generation is disabled by default

## Project Structure

### Top-Level Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM config: Swift 5.9, macOS 14+, executable target + test target, Yams dependency |
| `CLAUDE.md` | Developer guidance, build commands, architecture overview, conventions |
| `.gitignore` | Ignores .build/, .swiftpm/, DerivedData/, .DS_Store, Package.resolved |
| `Resources/AppIcon.icns` | Application icon |
| `Resources/DefaultAvatar.png` | Fallback avatar image |

### App Layer

| File | Contents | Summary |
|------|----------|---------|
| `App/SwiftTavernApp.swift` | `SwiftTavernApp : App` | Entry point. WindowGroup with hiddenTitleBar (1200x750). Command menu: Cmd+N (new chat), Cmd+Shift+N (new character), Cmd+F (search), Cmd+, (settings). |
| `App/AppState.swift` | `AppState : @Observable` | Central state container. Owns all storage services (including PresetStorageService). Holds characters, selectedCharacter, currentChat, groups, worldInfoBooks, personas, presets. Methods: `loadAll()`, `restoreSession()`, `scheduleSettingsSave()` (500ms debounce), `currentAPIConfiguration()`, `currentLLMService()`, `imageGenService()`, `imageGenAPIKey()`. Enum `SidebarItem` for navigation. Properties: `devLogger`, `activePresetName`. |

### Models

| File | Contents | Summary |
|------|----------|---------|
| `Models/Character.swift` | `TavernCardV2`, `CharacterData`, `CharacterEntry`, `AnyCodable` | TavernCardV2 spec: name, description, personality, scenario, firstMes, mesExample, alternateGreetings, characterBook, systemPrompt, postHistoryInstructions, tags. `CharacterEntry` wraps a loaded card with filename + avatarData. |
| `Models/ChatMessage.swift` | `ChatMessage`, `ChatMetadata`, `ChatSession` | Message: name, isUser, sendDate (ISO8601), mes (content), swipes (alternative responses), imageURL (optional path to generated image), imagePrompt (optional). `hasImage` computed property. Metadata: userName, characterName, createDate. Session: metadata + messages array. |
| `Models/APIConfiguration.swift` | `APIConfiguration` | Resolved config: apiType, apiKey, baseURL, model, generationParams. Property `effectiveBaseURL` resolves provider default. |
| `Models/Settings.swift` | `AppTheme`, `AppSettings`, `APIType`, `APIConfigurationData` | AppSettings: activeAPI, userName, theme, chatStyle, advancedMode, experimentalFeatures, apiKeys, imageGenerationSettings, characterPersonas, pinnedCharacters, developerMode, sidebarWidth, chatInputHeight, uiScale. APIType enum: openai/claude/gemini/ollama/openrouter/novelai with defaultModels, requiresAPIKey. |
| `Models/CharacterBook.swift` | `CharacterBook`, `CharacterBookEntry`, `EntryPosition` | Embedded world info in character cards. Entries with keys, content, position, priority. EntryPosition: beforeChar/afterChar/beforeExample/afterExample/atDepth. |
| `Models/WorldInfo.swift` | `WorldInfo`, `WorldInfoEntry` | Standalone world info books. Custom Codable handles SillyTavern field alternates (key/keys, order/insertion_order, disable/enabled). |
| `Models/Persona.swift` | `Persona` | User identity: name, description, optional avatarFilename. |
| `Models/Group.swift` | `CharacterGroup`, `GroupActivationStrategy` | Group chat config: members (character filenames), activation strategy (natural/roundRobin/random/manual). |
| `Models/GenerationParameters.swift` | `GenerationParameters` | LLM params: maxTokens (2048), temperature (0.7), topP, topK, frequencyPenalty, presencePenalty, repetitionPenalty, stopSequences, streamResponse. Advanced sampling params: minP, topA, typicalP, TFS, mirostatMode/Tau/Eta, noRepeatNgramSize, minLength, smoothingFactor/Curve, dynaTempEnabled/Low/High/Exponent, seedValue, contextSize, encoderRepetitionPenalty. |
| `Models/ChatStyle.swift` | `ChatStyle`, `CodableColor` | Message display styling. Three text colors: quoted (dialogue), italic/action, narrative. Defaults for dark mode (`.default`) and light mode (`.lightDefault`). `adaptedForAppearance()` auto-switches if colors too bright for light mode. |
| `Models/ChatPreset.swift` | `ChatPreset` | Named generation parameter presets. Fields: name, generationParameters. Identifiable via name. Compatible with SillyTavern preset format. |
| `Models/ImageGenerationSettings.swift` | `ImageGenerationSettings` | Image gen config: `ImageGenProvider` enum (dalle/stability/openrouter/novelai/custom), `ImageTriggerMode` (manual/everyNMessages/injectedPrompt), `ImageSize`, `ImageQuality`, `ImageDisplaySize`. API key management with shared key support via `sharedTextProvider`. Scene prompt template, injection prompt. |

### Services — LLM

| File | Contents | Summary |
|------|----------|---------|
| `Services/LLM/LLMService.swift` | `LLMService` protocol, `LLMMessage`, `MessageRole`, `LLMError` | Protocol: `sendMessage()` → `AsyncThrowingStream<String>` (streaming), `sendMessageComplete()` → `String` (non-streaming). Roles: system/user/assistant. |
| `Services/LLM/LLMServiceFactory.swift` | `LLMServiceFactory` | Factory: `create(for: APIType)` → returns provider-specific LLMService implementation. |
| `Services/LLM/OpenRouterService.swift` | `OpenRouterService : LLMService` | OpenAI-compatible with X-Title/HTTP-Referer headers. Streams SSE, parses delta.content. |
| `Services/LLM/OpenAIService.swift` | `OpenAIService : LLMService` | Chat Completions API. Streaming: delta.content. Non-streaming: message.content. |
| `Services/LLM/ClaudeService.swift` | `ClaudeService : LLMService` | Anthropic Messages API. Separates system messages. Ensures user/assistant alternation. Streams content_block_delta events. |
| `Services/LLM/GeminiService.swift` | `GeminiService : LLMService` | streamGenerateContent endpoint. Maps roles: assistant→model. Parses candidates[0].content.parts[0].text. |
| `Services/LLM/OllamaService.swift` | `OllamaService : LLMService` | Wraps OpenAIService with localhost:11434/v1. No API key needed. |
| `Services/LLM/NovelAIService.swift` | `NovelAIService : LLMService` | NovelAI text generation. Completion-style API (converts chat messages to single prompt). Streams SSE with `{ "token": "text" }` format. Supports extensive sampling params (minP, typicalP, TFS, Mirostat). Default models: llama-3-erato-v1, kayra-v1, clio-v1. Base URL: `https://text.novelai.net`. |
| `Services/LLM/SSEParser.swift` | `SSEParser`, `SSEEvent` | Parses Server-Sent Events lines. Handles "data:", "event:" prefixes, [DONE] terminator. |

### Services — Image Generation

| File | Contents | Summary |
|------|----------|---------|
| `Services/ImageGen/ImageGenerationService.swift` | `ImageGenerationService` protocol, `ImageGenError` | Protocol: `generateImage(prompt:negativePrompt:settings:apiKey:)` → `Data`. Error types for API, format, auth failures. |
| `Services/ImageGen/ImageGenServiceFactory.swift` | `ImageGenServiceFactory` | Factory: `create(for: ImageGenProvider)` → returns provider-specific implementation. |
| `Services/ImageGen/DalleImageService.swift` | `DalleImageService : ImageGenerationService` | OpenAI DALL-E 3 integration. Supports quality settings (standard/hd). |
| `Services/ImageGen/StabilityImageService.swift` | `StabilityImageService : ImageGenerationService` | Stability AI integration with negative prompt support. |
| `Services/ImageGen/OpenRouterImageService.swift` | `OpenRouterImageService : ImageGenerationService` | Image models via OpenRouter chat completions API. |
| `Services/ImageGen/NovelAIImageService.swift` | `NovelAIImageService : ImageGenerationService` | NovelAI Diffusion API. Handles zip extraction and deflate decompression for image responses. Supports v3, v4+ models with different parameter sets. |
| `Services/ImageGen/ScenePromptBuilder.swift` | `ScenePromptBuilder` | Uses the main LLM to translate recent chat messages into visual prompts for image generation. Template vars: {{char}}, {{user}}, {{char_description}}. |

### Services — PNG

| File | Contents | Summary |
|------|----------|---------|
| `Services/PNG/PNGChunkReader.swift` | `PNGChunkReader`, `PNGError` | Reads PNG chunks: validates signature, iterates [length, type, data, CRC]. Extracts tEXt chunks by keyword (key\0text). |
| `Services/PNG/PNGChunkWriter.swift` | `PNGChunkWriter` | Writes/removes PNG tEXt chunks. CRC32 via zlib. Inserts before IEND. |
| `Services/PNG/CharacterCardParser.swift` | `CharacterCardParser` | High-level: `parse()` tries 'chara' then 'ccv3' keywords, decodes base64 JSON to TavernCardV2. `embed()` encodes card to base64, writes to PNG. |

### Services — Storage

| File | Contents | Summary |
|------|----------|---------|
| `Services/Storage/DataDirectoryManager.swift` | `DataDirectoryManager` | Root: ~/Library/Application Support/SwiftTavern/. Creates subdirs: characters, chats, groups, "group chats", worlds, user, "User Avatars", backgrounds, themes, backups, thumbnails, generated_images, presets. |
| `Services/Storage/CharacterStorageService.swift` | `CharacterStorageService` | CRUD for character PNG files. `importCharacter()` handles PNG (embedded card) or JSON (bare CharacterData, TavernCardV2, or SillyTavern wrapper). Creates minimal 1x1 PNG if no avatar. |
| `Services/Storage/ChatStorageService.swift` | `ChatStorageService` | Thread-safe JSONL I/O via DispatchQueue. First line = metadata, subsequent = messages. Methods: createChat, loadChat, appendMessage, rewriteChat, listChats (sorted newest-first), searchChats, exportChat. |
| `Services/Storage/SettingsStorageService.swift` | `SettingsStorageService` | JSON persistence of AppSettings. Pretty-printed, sorted keys. Returns .default on missing/corrupt file. |
| `Services/Storage/WorldInfoStorageService.swift` | `WorldInfoStorageService` | JSON world info books in worlds/ directory. |
| `Services/Storage/PersonaStorageService.swift` | `PersonaStorageService` | personas.json + avatar files in "User Avatars/". Defaults to [Persona(name: "User")]. |
| `Services/Storage/GroupStorageService.swift` | `GroupStorageService` | JSON group definitions in groups/ directory. |
| `Services/Storage/GroupChatStorageService.swift` | `GroupChatStorageService` | JSONL group chats in "group chats/" directory. Similar to ChatStorageService. |
| `Services/Storage/PresetStorageService.swift` | `PresetStorageService` | JSON presets in presets/ directory. Always includes "Default" preset. Import/export SillyTavern preset format with field mapping. |

### Services — Other

| File | Contents | Summary |
|------|----------|---------|
| `Services/PromptBuilder.swift` | `PromptBuilder` | Assembles LLM context: system prompt → description → personality → scenario → persona → character book (constant + keyword-triggered) → world info (constant + triggered) → few-shot examples → chat history → post-history instructions. Template vars: {{char}}, {{user}}. scanDepth controls how far back to search for keywords. |
| `Services/DevLogger.swift` | `DevLogger` | Thread-safe `@Observable` logger. LogEntry: timestamp, type (REQ/RES/ERR/INFO), message. Max 500 entries. Used throughout ViewModels for API debugging. |

### Utilities

| File | Contents | Summary |
|------|----------|---------|
| `Utilities/Extensions/String+Extensions.swift` | String extensions | `sanitizedFilename()`, `replacingTemplateVars(char:, user:)`, `truncated(to:)` |
| `Utilities/Extensions/Data+PNG.swift` | Data extensions | `readUInt32()` (big-endian), `uint32BigEndian()`, `pngSignature`, `isPNG` |
| `Utilities/Extensions/Date+Formatting.swift` | Date/String extensions | `chatDateString`, `chatFileDateString` (filename-safe), `relativeDisplayString` ("2d ago"), String `chatDate` parser |
| `Utilities/FileManagerExtensions.swift` | FileManager extension | `appSupportDirectory` → ~/Library/Application Support/SwiftTavern/ (fallback ~/.swifttavern/) |
| `Utilities/ImageCache.swift` | `ImageCache` | Thread-safe NSCache wrapper. 200 image limit, 100MB budget. Concurrent DispatchQueue. |

### ViewModels

| File | Contents | Summary |
|------|----------|---------|
| `ViewModels/ChatViewModel.swift` | `ChatViewModel : @Observable` | Chat logic: sendMessage → generateResponse (builds prompt, streams with 120s timeout). Swipes (alternative responses). Greeting swipes (alternateGreetings). Search across chats. Edit/delete/regenerate messages. New/load/delete chats. Export/import. Image generation: `generateImageForCurrentScene()` (two-step pipeline), `autoGeneratePromptForEditor()`, `generateImageWithCustomPrompt()`, `openImagePromptEditor()`. State: isGeneratingImage, imageGenerationError, messagesSinceLastImage, showingImagePromptEditor, imageEditorPrompt/negativePrompt. |
| `ViewModels/SettingsViewModel.swift` | `SettingsViewModel : @Observable`, `SettingsSection` | Settings management. API switching, model fetching (live OpenRouter list), connection testing. Image generation API setup and testing. SillyTavern import (characters, chats, worlds, presets, personas, avatars from multiple directory layouts). Data export. Theme application. Toast messages. |
| `ViewModels/CharacterListViewModel.swift` | `CharacterListViewModel : @Observable` | Character sidebar: filtered list (by name/tags), import (PNG/JSON), export, create, edit, delete. `selectCharacter()` loads or creates a chat. |
| `ViewModels/CharacterEditorViewModel.swift` | `CharacterEditorViewModel : @Observable` | Character creation/editing form. Avatar picker. Validates name, builds TavernCardV2, embeds in PNG via CharacterCardParser. |
| `ViewModels/GroupChatViewModel.swift` | `GroupChatViewModel : @Observable` | Group chat: create/select groups, send messages, generate responses with speaker selection (natural/roundRobin/random). |
| `ViewModels/PersonaViewModel.swift` | `PersonaViewModel : @Observable` | Persona CRUD: create, delete, select active, avatar management, import from SillyTavern. |
| `ViewModels/WorldInfoViewModel.swift` | `WorldInfoViewModel : @Observable` | World lore CRUD: create/delete books, add/remove entries, save, import. |

### Views

| File | Contents | Summary |
|------|----------|---------|
| `Views/MainView.swift` | `MainView` | Root layout: HStack with sidebar + detail. Inline sidebar toggle (hiddenTitleBar). Routes SidebarItem to detail views. Onboarding sheet on first launch. |
| `Views/OnboardingView.swift` | `OnboardingView` | First-launch modal (600x650). Features overview, "Bring Your Own API Key" notice (recommends OpenRouter). |
| `Views/Sidebar/SidebarView.swift` | `SidebarView`, `ConversationRowView` | Main sidebar: search bar, character conversation list with avatars/dates, pinning support, optional Groups section, bottom nav (Characters, World Lore, Personas, Settings). Context menus for edit/export/delete. |
| `Views/Sidebar/CharacterRowView.swift` | `CharacterRowView` | Individual character row display. |
| `Views/Character/CharacterListView.swift` | `CharacterListView` | Grid/list of all characters with search. |
| `Views/Character/CharacterDetailView.swift` | `CharacterDetailView` | Character info display (avatar, description, personality, scenario). |
| `Views/Character/CharacterEditorView.swift` | `CharacterEditorView` | Create/edit form: name, description, personality, scenario, first message, alternate greetings, system prompt, tags, avatar. |
| `Views/Character/CharacterImportView.swift` | `CharacterImportView` | File picker for PNG/JSON imports. |
| `Views/Chat/ChatView.swift` | `ChatView` | Main chat area: scrollable message list, input bar, chat history picker, search overlay, chat style editor sheet. Image display and camera button for image generation triggers. |
| `Views/Chat/MessageBubbleView.swift` | `MessageBubbleView` | Single message: avatar, name, timestamp, styled text (MarkdownTextView), swipe arrows, context menu (copy/edit/regenerate/delete). Image display for messages with generated images. User messages: accent background. Character: control background. |
| `Views/Chat/ChatInputView.swift` | `ChatInputView` | Text input with send button. Enter/Shift+Enter or Cmd+Enter based on settings. |
| `Views/Chat/ChatStyleEditorView.swift` | `ChatStyleEditorView` | Color pickers for quoted/action/narrative text, font size slider, live preview, reset to defaults. |
| `Views/Chat/ChatHistoryPickerView.swift` | `ChatHistoryPickerView` | List of previous chats for a character, sorted by date. |
| `Views/Chat/StreamingIndicatorView.swift` | `StreamingIndicatorView` | Animated dots while generating response. |
| `Views/Chat/ImagePromptEditorView.swift` | `ImagePromptEditorView` | Sheet for editing/customizing image prompts before generation. "Auto-generate from scene" button uses LLM. Prompt and negative prompt editors. Provider-specific hints. |
| `Views/Settings/SettingsView.swift` | `SettingsView`, `DataImportExportView` | Settings sidebar (180px) + scrollable content. Sections: API, General, Chat, Generation, Image Generation, Experimental, Data. Toast overlay. |
| `Views/Settings/APISettingsView.swift` | API settings | Provider picker, API key field (show/hide), model list with search/groups, base URL, connection test. |
| `Views/Settings/GenerationSettingsView.swift` | `GenerationSettingsView` | Sliders/fields for temperature, topP, topK, maxTokens, penalties, stop sequences. Advanced mode: minP, topA, typicalP, TFS, Mirostat, smoothing, dynamic temperature, context size. |
| `Views/Settings/PersonaSettingsView.swift` | `PersonaSettingsView` | Persona list with avatars, create new form, set active, delete. |
| `Views/Settings/PersonaPageView.swift` | `PersonaPageView` | Full-page persona editor. |
| `Views/Group/GroupChatView.swift` | `GroupChatView` | Group chat interface with multi-character messages. |
| `Views/Group/GroupEditorView.swift` | `GroupEditorView` | Create/edit groups: name, select members, activation strategy. |
| `Views/WorldInfo/WorldInfoListView.swift` | `WorldInfoListView` | List of world info books with create/import/delete. |
| `Views/WorldInfo/WorldInfoEditorView.swift` | `WorldInfoEditorView` | Edit entries: keys, content, position, constant flag, secondary keys, case sensitivity. |
| `Views/Components/AvatarImageView.swift` | `AvatarImageView` | Cached avatar display with fallback initials, size customization. |
| `Views/Components/MarkdownTextView.swift` | `MarkdownTextView` | Renders chat text with ChatStyle coloring (quoted/action/narrative). Adapts colors for light/dark mode. Code block rendering. Falls back to standard Markdown. |
| `Views/Components/SearchBarView.swift` | `SearchBarView` | Reusable search field with clear button. |
| `Views/Components/GlobalSearchView.swift` | `GlobalSearchView` | Full-screen search overlay. Searches character names and all chat messages. Results grouped by character with avatars, snippet display with context. Navigation callbacks to load character + chat. |

### Tests

| File | Summary |
|------|---------|
| `Tests/SwiftTavernTests/Models/CharacterTests.swift` | TavernCardV2 JSON decoding |
| `Tests/SwiftTavernTests/Models/ChatMessageTests.swift` | ChatMessage encoding/decoding |
| `Tests/SwiftTavernTests/Services/CharacterCardParserTests.swift` | PNG chunk read/write, card embedding |
| `Tests/SwiftTavernTests/Services/PNGChunkTests.swift` | PNG chunk I/O edge cases |
| `Tests/SwiftTavernTests/Services/ChatStorageServiceTests.swift` | JSONL chat CRUD, thread safety |
| `Tests/SwiftTavernTests/Services/PromptBuilderTests.swift` | Prompt assembly pipeline |
| `Tests/SwiftTavernTests/ViewModels/ChatViewModelTests.swift` | Message sending, generation, swipes |
| `Tests/SwiftTavernTests/FeatureTests.swift` | Integration: character import, chat flow, settings sections |
| `Tests/SwiftTavernTests/ImprovementTests.swift` | Performance and compatibility |
| `Tests/SwiftTavernTests/UIChangesTests.swift` | UI behavior validation |
| `Tests/SwiftTavernTests/OpenRouterAPITest.swift` | OpenRouter connectivity (requires API key, skipped by default) |

## Key Data Flows

### Sending a Message
`ChatInputView` → `ChatViewModel.sendMessage()` → append `ChatMessage` to `AppState.currentChat` → `ChatStorageService.appendMessage()` (disk) → `generateResponse()` → `PromptBuilder.buildMessages()` → `LLMService.sendMessage()` (stream) → chunks accumulated → finalize to chat → `ChatStorageService.rewriteChat()` (persist)

### Generating an Image
`ChatView` (camera button or auto-trigger) → `ChatViewModel.generateImageForCurrentScene()` → Step 1: `ScenePromptBuilder` uses main LLM to create visual prompt from recent chat → Step 2: `ImageGenServiceFactory.create()` → `ImageGenerationService.generateImage()` → image data saved to `generated_images/{CharName}/` → `imageURL` set on ChatMessage → `ChatStorageService.rewriteChat()` (persist)

### Importing a Character
File picker → `CharacterListViewModel.importCharacter(from: url)` → `CharacterStorageService.importCharacter()` → PNG: `CharacterCardParser.parse()` (reads tEXt chunk, base64 decodes JSON) / JSON: direct decode → saves to characters/ → reloads `appState.characters`

### LLM Provider Switch
Settings UI → `SettingsViewModel.switchAPI()` → loads `APIConfigurationData` for provider → retrieves API key from `appState.settings.apiKeys` → updates model list → `appState.saveSettings()`

### Prompt Assembly
`PromptBuilder.buildMessages(chat, character, settings, persona, worldInfoBooks)` → system prompt → character description/personality/scenario → active persona description → character book entries (constant + keyword-triggered via scanDepth) → world info entries (constant + triggered) → few-shot examples (parsed from mesExample) → chat history messages → post-history instructions → template var replacement ({{char}}/{{user}})

## Persistence Formats

| Data | Format | Location |
|------|--------|----------|
| Characters | PNG with base64 JSON in tEXt chunk (key: "chara") | ~/Library/Application Support/SwiftTavern/characters/ |
| Chats | JSONL (line 1 = metadata, lines 2+ = messages) | ~/Library/Application Support/SwiftTavern/chats/{CharName}/ |
| Settings | JSON (pretty-printed, sorted keys) | ~/Library/Application Support/SwiftTavern/user/settings.json |
| API Keys | JSON (in `apiKeys` field of settings) | ~/Library/Application Support/SwiftTavern/user/settings.json |
| World Info | JSON files | ~/Library/Application Support/SwiftTavern/worlds/ |
| Personas | personas.json + avatar PNGs | ~/Library/Application Support/SwiftTavern/user/ + User Avatars/ |
| Groups | JSON files | ~/Library/Application Support/SwiftTavern/groups/ |
| Group Chats | JSONL files | ~/Library/Application Support/SwiftTavern/group chats/ |
| Presets | JSON files | ~/Library/Application Support/SwiftTavern/presets/ |
| Generated Images | PNG files | ~/Library/Application Support/SwiftTavern/generated_images/{CharName}/ |
