# STYLE.md — UI Changes & Improvements

This document records UI changes made to improve usability, accessibility, and visual consistency.

## System Font Size Default (Task 4)

- **ChatStyle.systemDefaultFontSize**: The default chat font size now reads from `NSFont.systemFontSize` instead of a hardcoded `13`. This ensures the app respects the user's macOS system font size preference.
- **MarkdownTextView**: Fallback font sizes reference `ChatStyle.systemDefaultFontSize` instead of `13`.

## Sidebar Navigation (Task 2)

- **Reduced empty space**: Navigation buttons now use `1pt` spacing between items (was `0` with large padding), and have `8px` horizontal padding so text fills more of the available width.
- **Icon alignment**: Icon frame width increased from `16` to `18` for better optical balance with text.
- **Horizontal padding**: Navigation section now has `4px` horizontal padding to align with conversation list items.

## UI Improvements (Task 3)

### 1. Message Bubble Padding (MessageBubbleView)
- Increased vertical padding from `6px` to `10px` for better readability and visual breathing room between message content and bubble edges.

### 2. Message Hover Feedback (MessageBubbleView)
- Added subtle opacity change on hover (`0.95` → `1.0`) to provide visual feedback when the user mouses over a message bubble.

### 3. Swipe Control Accessibility (MessageBubbleView)
- Added `.accessibilityLabel("Previous response")` and `.accessibilityLabel("Next response")` to swipe navigation chevron buttons for screen reader support.

### 4. Chat Input Focus Ring (ChatInputView)
- Added a `@FocusState` focus indicator to the message text editor. When focused, a subtle accent-colored border appears around the input area.
- Added `.accessibilityLabel("Message input")` to the text editor.

### 5. Drag Handle Size (ChatInputView)
- Increased drag handle frame height from `8px` to `12px` and circle indicators from `4px` to `5px` for a better grab target.

### 6. Chat History Hover Effects (ChatHistoryPickerView)
- Added hover state tracking to chat history rows with a subtle background highlight on hover, matching the sidebar's hover pattern.

### 7. Persona Row Padding (PersonaPageView)
- Increased persona list row vertical padding from `2px` to `6px` for better readability and click target size.

### 8. World Info Book Truncation (WorldInfoListView)
- Added `.truncationMode(.tail)` to book names in the sidebar list to handle long names gracefully.
- Added `.help(book.name)` tooltip so users can see the full book name on hover.

### 9. Chat Header Accessibility (ChatView)
- Added descriptive accessibility labels to all header icon buttons:
  - Bookmark filter, auto-scroll toggle, chat style, search, new chat, and image generation buttons.
- Added `.lineLimit(1)` to the character name in the header to prevent overflow.

### 10. Settings Accessibility (GenerationSettingsView, ChatStyleEditorView)
- Added `.accessibilityValue()` to all generation parameter sliders so screen readers announce the current value.
- Added `.accessibilityLabel()` to color pickers in the chat style editor (quoted, action, thinking, narrative text colors).
- Normalized preview section padding to `12px` in ChatStyleEditorView.

## Reference Image Support (Task 1)

- **ImageGenerationService protocol**: Added optional `referenceImage: Data?` parameter to `generateImage()`.
- **NovelAI**: When a reference image is provided, uses `img2img` action with the character avatar, passing `strength` and `noise` parameters.
- **OpenRouter**: When a reference image is provided, sends multimodal content with the image as a `image_url` type alongside the text prompt.
- **ImagePromptEditorView**: Added a "Use Character Avatar as Reference" toggle with an influence strength slider (10%–90%) and avatar preview, visible only for providers that support reference images.
- **ImageGenerationSettings**: Added `useReferenceImage` (default: false) and `referenceImageStrength` (default: 0.6) fields with backward-compatible decoding.
