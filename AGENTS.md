# PiDesktop — Project Knowledge

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
