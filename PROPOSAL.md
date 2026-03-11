# Image Generation Feature Proposal

## Overview

A two-step architecture: the **main LLM** summarizes the current scene into a concise visual prompt, then an **image generation API** produces the image. This is necessary because image gen models need distilled descriptive prompts, not raw chat history.

---

## 1. New Data Models

### New file: `Models/ImageGenerationSettings.swift`

A `Codable` struct added to `AppSettings` containing:

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `enabled` | `Bool` | `false` | Master toggle |
| `provider` | `ImageGenProvider` | `.openaiDalle` | Which image API to use |
| `model` | `String` | `"dall-e-3"` | Model identifier |
| `baseURL` | `String?` | `nil` | Custom endpoint override |
| `imageSize` | `ImageSize` | `.square1024` | Output dimensions |
| `quality` | `ImageQuality` | `.standard` | HD option (DALL-E) |
| `triggerMode` | `ImageTriggerMode` | `.manual` | How images are triggered |
| `messageInterval` | `Int` | `5` | For `everyNMessages` mode |
| `injectionPrompt` | `String` | *(see section 5)* | Prompt injected into LLM context |
| `scenePromptTemplate` | `String` | *(see section 6)* | Template for scene-to-prompt translation |
| `useMainAPIForSceneSummary` | `Bool` | `true` | Use chat LLM for prompt distillation |

### Enums

- `ImageGenProvider` — `.openaiDalle`, `.stabilityAI`, `.openrouter`, `.custom` (each with `displayName`, `defaultModels`, `keychainKey`, `defaultBaseURL`)
- `ImageTriggerMode` — `.manual`, `.everyNMessages`, `.injectedPrompt`
- `ImageSize` — `.square1024`, `.landscape1792x1024`, `.portrait1024x1792`
- `ImageQuality` — `.standard`, `.hd`

### Modify `Models/Settings.swift`

Add `imageGenerationSettings: ImageGenerationSettings` to `AppSettings` with backward-compatible decoding (`decodeIfPresent`).

### Modify `Models/ChatMessage.swift`

Add optional `imageURL: String?` and `imagePrompt: String?` fields. Add computed `hasImage: Bool`.

---

## 2. Service Layer

### New `Services/ImageGen/` directory (5 files)

| File | Purpose |
|------|---------|
| `ImageGenerationService.swift` | Protocol: `generateImage(prompt:, settings:, apiKey:) async throws -> Data` + `ImageGenError` enum |
| `DalleImageService.swift` | OpenAI DALL-E — POST `/v1/images/generations`, response format `b64_json` |
| `StabilityImageService.swift` | Stability AI — POST `/v1/generation/{model}/text-to-image`, extract from `artifacts[0].base64` |
| `OpenRouterImageService.swift` | Thin wrapper for OpenRouter image models |
| `ImageGenServiceFactory.swift` | Factory: `create(for: ImageGenProvider) -> ImageGenerationService` |

### New `Services/ImageGen/ScenePromptBuilder.swift`

Builds an `[LLMMessage]` asking the main LLM to distill the current scene into a concise image prompt. Takes character description, persona, recent messages (last 5-10), and scenario.

### Modify `Services/Storage/DataDirectoryManager.swift`

Add `"generated_images"` subdirectory. Images stored as `{timestamp}_{UUID}.png` under `generated_images/{CharacterName}/`.

### Modify `Services/Storage/SecretsStorageService.swift`

Add convenience methods for image gen API keys using `ImageGenProvider.keychainKey`.

### Modify `Services/PromptBuilder.swift`

Add optional `imageInjectionPrompt: String?` parameter to `buildMessages()`. When non-nil, append it as a post-history instruction so the LLM knows to emit `[GENERATE_IMAGE]` tags.

---

## 3. ViewModel Changes

### Modify `ViewModels/ChatViewModel.swift`

New properties:

- `isGeneratingImage: Bool`
- `imageGenerationError: String?`
- `messagesSinceLastImage: Int`

New methods:

- `generateImageForCurrentScene()` — orchestrates the two-step flow: LLM scene summary → image gen API → save PNG to disk → create image ChatMessage → append to chat
- `checkAutoImageTrigger()` — called after `finalizeResponse()`: checks interval counter or scans for `[GENERATE_IMAGE]` tag in the last response, strips the tag from displayed text

Modifications:

- `finalizeResponse()` — call `checkAutoImageTrigger()` after saving
- When `injectedPrompt` mode is active, pass the injection prompt through to `PromptBuilder`

### Modify `ViewModels/SettingsViewModel.swift`

Add bindable properties for all `ImageGenerationSettings` fields, save/load/test methods.

---

## 4. View Changes

### New file: `Views/Settings/ImageGenerationSettingsView.swift`

- Provider picker, API key field, model field, base URL
- Image size and quality pickers
- Trigger mode picker with conditional UI (interval stepper, injection prompt editor)
- Scene prompt template editor
- Test button that generates a sample image

### Modify `Views/Settings/SettingsView.swift`

Add `.imageGeneration` section (icon: `photo.badge.plus`), visible under experimental features.

### Modify `Views/Chat/MessageBubbleView.swift`

When `message.hasImage`, render an `Image` from the file path below the text content. Rounded corners, max width ~400pt, aspect-fit. Context menu: Save Image, Copy Image, Regenerate Image.

### Modify `Views/Chat/ChatView.swift`

Add a camera/image button to the toolbar (visible when enabled). Show loading indicator during generation.

### Modify `Views/Chat/ChatInputView.swift`

Add a small camera icon button next to send for manual generation.

### Modify `App/AppState.swift`

Add `imageGenService() -> ImageGenerationService` and `imageGenAPIConfiguration()` accessors.

---

## 5. Example Injection Prompt (Default)

This is injected into the LLM context when `triggerMode == .injectedPrompt`:

```
[Image Generation Instructions]
You have the ability to request scene illustrations during the conversation.
When a visually significant moment occurs — such as arriving at a new location,
a dramatic change in scenery, a character's appearance changing, or an emotionally
impactful scene — include the exact tag [GENERATE_IMAGE] on its own line within
your response.

Guidelines for when to use [GENERATE_IMAGE]:
- When the scene transitions to a new environment or location
- When a character's appearance or outfit changes significantly
- During dramatic, climactic, or emotionally charged moments
- When the user explicitly asks to see something
- Do NOT use it for mundane conversation or minor actions
- Use it at most once per response
- Place it at the end of the paragraph describing the visual scene

Example usage in a response:
*The ancient door creaked open, revealing a vast underground cavern. Crystalline
formations jutted from every surface, casting prismatic light across the chamber.
A river of luminescent blue water carved through the center, its gentle glow
illuminating carved stone pillars that stretched impossibly high.*
[GENERATE_IMAGE]
```

---

## 6. Scene-to-Prompt Template (Default)

Sent to the main LLM to translate the current narrative into an image generation prompt:

```
Based on the recent conversation, describe the current scene as a visual image
prompt. Focus on:
- The physical environment/setting
- Character appearances (clothing, expression, posture)
- Lighting, colors, and mood
- Composition and perspective

Character appearance reference: {{char_description}}

Output ONLY a concise image generation prompt (2-4 sentences). Do not include
dialogue, narration, or any non-visual elements. Use descriptive, visual language
suitable for an AI image generator.
```

---

## 7. Key Design Decisions

- **Images as separate ChatMessages** (not embedded in assistant messages) — keeps JSONL clean, allows independent deletion
- **File-based storage** (not base64 in JSONL) — avoids bloating chat files
- **`[GENERATE_IMAGE]` tag is stripped** from displayed text after detection — user only sees the resulting image
- **Two-step generation** — LLM understands narrative context and distills it; image model gets a clean visual prompt
- **Separate API key** — users often use different providers for chat vs. images (e.g., OpenRouter for chat, DALL-E for images)

---

## 8. Implementation Order

1. Models (`ImageGenerationSettings`, modify `Settings`, modify `ChatMessage`)
2. Storage (`DataDirectoryManager`, `SecretsStorageService`)
3. Services (protocol, DALL-E, Stability, factory, `ScenePromptBuilder`)
4. AppState (accessors)
5. PromptBuilder (injection prompt support)
6. ChatViewModel (generation logic, triggers)
7. SettingsViewModel (image gen config binding)
8. Views (settings page, message rendering, chat buttons)
9. Tests (settings encoding, trigger logic, scene prompt builder)
