# Bourbaki — Project Knowledge

## Build

- `make build-ghostty-xcframework` — builds GhosttyKit from source (needs zig 0.15.2 via mise)
- `make build-app` — builds the macOS app (Debug)
- `make run-app` — builds + launches
- `make check` — format + lint

## Important Build Details

- **xcode-select must point to Xcode.app** (not CommandLineTools) for the zig build to find macOS SDK
- **Metal Toolchain required** — run `xcodebuild -downloadComponent MetalToolchain` if missing
- **Target uses Swift 5 language mode** (matches supacode) to avoid strict concurrency errors with NSView subclasses + C callbacks
- **`-lc++` linker flag required** — ghostty's static lib contains SPIRV-Cross/glslang C++ code
- **`-Xcc -Wno-incomplete-umbrella`** suppresses GhosttyKit umbrella header warnings
- **Deployment target: macOS 26.0** (running on macOS Tahoe; SwiftUICore linker issue with older targets)

## Code Signing

- App is signed with Apple Development certificate (team BQYU8UZ8T7)
- Xcode manages signing automatically
- Makefile no longer passes `CODE_SIGNING_ALLOWED=NO` — builds are properly signed
- `UNUserNotificationCenter` requires proper code signing; `osascript` is kept as fallback for unauthorized state
- GhosttyKit.xcframework contains a **static library** (`libghostty.a`) — must NOT be embedded in the app bundle (only linked). Embedding causes codesign failures.

## Ghostty Infrastructure

8 files ported from supacode (`/Users/tudoroancea/dev/supacode/supacode/Infrastructure/Ghostty/`):
- `GhosttyRuntime.swift` — singleton, app lifecycle, clipboard, config
- `GhosttySurfaceView.swift` — NSView with keyboard/mouse/IME/drag-drop (~1200 lines)
- `GhosttySurfaceBridge.swift` — action dispatch from ghostty → Swift callbacks
- `GhosttySurfaceState.swift` — @Observable state for a terminal surface
- `GhosttyTerminalView.swift` — SwiftUI NSViewRepresentable wrapper
- `GhosttySplitAction.swift` — split action enum
- `GhosttyShortcutManager.swift` — keybinding query + KeyboardShortcut display
- `SecureInput.swift` — secure keyboard input (password fields)

Changes from supacode originals:
- Stripped all Sentry, PostHog, ComposableArchitecture, Sharing imports
- Fixed `MainActor.assumeIsolated` calls in GhosttyRuntime C callbacks for Swift 5 mode compat
- Removed split menu items from context menu (simplified for single-pane)
- `nonisolated(unsafe)` on `ghosttySelection` static property
- Simplified `SecureInput.deinit` to avoid main-actor property access

## App Keybindings

All app-level keybindings are defined in `Bourbaki/App/AppShortcuts.swift`. They are **unbound from ghostty** at init time via `--keybind=<bind>=unbind` CLI args passed to `ghostty_init` (same pattern as supacode). The ghostty unbind format uses `ctrl`/`alt`/`shift`/`super` modifiers joined by `+`.

## Settings & Tool Configuration

- **Settings page** opened via `Cmd+,` (native SwiftUI `Settings` scene)
- `ToolSettings.swift` in Services — persists commands in `UserDefaults` (`toolCommand.agent/git/diff`)
- Defaults: `pi`, `lazygit`, `lumen diff`
- At startup, `checkToolAvailability()` runs `which` against an augmented PATH (adds homebrew, .local/bin, cargo, bun, mise shims)
- `ToolSettings.toolErrors` maps `TabType → error message` for unavailable tools
- Dashboard shows a warning banner at the bottom when tools are missing
- Creating a tool tab when the tool is unavailable shows an alert with "Open Settings" button
- `TabType.command` was removed — commands are now resolved via `ToolSettings.command(for:)`

## Tool Naming (UI)

Tools are presented in the UI with generic names decoupled from the underlying CLI tools:
- **agent** (was "pi") — `TabType.agent`, runs `exec pi`
- **git** (was "lazygit") — `TabType.git`, runs `exec lazygit`
- **diff** (was "lumen diff") — `TabType.diff`, runs `exec lumen diff`
- **editor** (was "zed") — `ExternalAppLauncher.openInEditor`, runs `open -a Zed`

All menus, context menus, keybind labels, and help strings use these generic names.

Key bindings use `Cmd+Ctrl` and `Cmd+Shift` combos to avoid collisions with both ghostty defaults (`Cmd+T/W/N/1-9`) and pi keybindings (`Ctrl+P/L/C/D`).

## Dashboard / Recent Worktrees

- `DashboardView` shown in detail pane when no worktree is selected (app startup)
- `RecentWorktreeStore` persists to `~/Library/Application Support/Bourbaki/recent_worktrees.json`
- Up to 20 recent entries, sorted by last opened
- `Cmd+1-9` opens recent worktrees from dashboard (reuses tab shortcuts when no worktree active)
- When a worktree is selected, `Cmd+1-9` reverts to normal tab switching behavior
- Entries show display name, path, relative time; invalid paths are grayed out with warning icon

## Theme

- Rosé Pine (dark) + Rosé Pine Dawn (light) — auto-switches via `NSAppearance.isDark`
- All adaptive colors use `NSColor(name:dynamicProvider:)` under the hood
- `RosePineTheme.swift` has `RosePine.Dark.*` / `RosePine.Dawn.*` for explicit variant access
- `WindowStyling.swift` has `.rosePineWindow()` modifier — sets transparent titlebar + base background
- Sidebar uses `.scrollContentBackground(.hidden)` + `RosePine.surface` to override system sidebar color
- `RosePine.nsBase` / `RosePine.nsSurface` are `NSColor` variants for window chrome

## Adding Files to Xcode Project

The `.xcodeproj/project.pbxproj` must be manually edited to add new Swift files:
1. Add a `PBXBuildFile` entry (build ref → file ref)
2. Add a `PBXFileReference` entry (file path)
3. Add to the appropriate `PBXGroup` children list
4. Add the build file ref to `PBXSourcesBuildPhase`
Use the existing ID patterns (e.g. `AA0007...` / `BB0007...` / `CC0007...` for the App group).
