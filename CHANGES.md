# Changes

## 2026-03-09 - UI Polish & Bug Fixes

### 1. Light Mode Text Readability
- Chat message text (quoted, action, narrative) was nearly invisible in light mode due to very high RGB values (0.85-0.9) optimized only for dark backgrounds.
- Added `ChatStyle.lightDefault` with darker, readable colors for light mode (dark gold for quotes, dark green for actions, near-black for narrative).
- `MarkdownTextView` now detects the current color scheme and automatically adapts chat colors when the user's saved style has light-colored text on a light background.

### 2. Onboarding & Keychain Access
- Updated the onboarding popup to clearly tell users to bring their own API key and that OpenRouter is recommended.
- Keychain access is requested once at startup via `SecretsStorageService.init()` which calls `KeychainHelper.loadAll()` in a single batch query. Subsequent reads use an in-memory cache with no additional keychain prompts.

### 3. Experimental Tab Performance
- Fixed UI hang when selecting the Experimental tab in Settings. The `saveConfiguration()` calls on toggle changes are now dispatched asynchronously via `Task { @MainActor in }` to avoid blocking the UI thread during file I/O.

### 4. Removed Personas from Settings
- Removed the Personas section from the Settings sidebar since Personas is already accessible from the main sidebar navigation (left panel). This eliminates redundancy.

### 5. Window Titlebar Cleanup
- Changed window style from `.titleBar` to `.hiddenTitleBar` to remove the grey bar at the top of the window.
- Added a slim inline sidebar toggle button at the top of the detail content area.
- Background now fills uniformly with `windowBackgroundColor`.

### 6. Sidebar Left Spacing
- Reduced horizontal padding on the search bar (8pt -> 4pt), navigation buttons (8pt -> 4pt), and conversation rows (8pt -> 4pt) to bring UI elements closer to the left edge of the sidebar for a more polished appearance.
