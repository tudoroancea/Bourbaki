Now I have a comprehensive understanding of both the existing supacode project and pi. Let me create the detailed implementation plan.

---

# Implementation Plan: Pi Desktop App (macOS)

## 1. Analysis of the Existing Supacode Codebase

### What Supacode Does Well (reusable)

The existing codebase has **excellent, production-quality libghostty integration**:

1. **`GhosttyRuntime`** — Singleton that initializes `ghostty_app_t`, handles config loading, clipboard, color scheme sync, surface registration, and the core runtime callbacks (`wakeup_cb`, `action_cb`, `read_clipboard_cb`, `write_clipboard_cb`, `close_surface_cb`). This is ~300 lines and nearly directly reusable.

2. **`GhosttySurfaceView`** — Full `NSView` subclass (~700 lines) handling keyboard input (with IME/marked text), mouse events, drag-and-drop, scrollbar, focus management, key translation, binding detection, and the complete `NSTextInputClient` protocol. This is the hardest part to get right and is **battle-tested**.

3. **`GhosttySurfaceBridge`** — Action dispatch handler that routes all ghostty actions (title changes, notifications, progress reports, splits, tabs, search, mouse shapes, etc.) to Swift callbacks. Critically, this is where **OSC 777 desktop notifications** are handled (`GHOSTTY_ACTION_DESKTOP_NOTIFICATION`).

4. **`GhosttySurfaceState`** — Observable state for a single terminal surface (title, progress, bell, etc.).

5. **`GhosttyTerminalView`** — SwiftUI `NSViewRepresentable` wrapper + `GhosttySurfaceScrollView`.

6. **`GhosttyShortcutManager`** — Queries ghostty config for keybinding triggers and converts them to SwiftUI `KeyboardShortcut`.

7. **`AppShortcuts`** — App-level keybinds that are **unbound from ghostty** at startup via `--keybind=<bind>=unbind` CLI args passed to `ghostty_init`.

8. **Build infrastructure** — Makefile for building `GhosttyKit.xcframework` from Zig source, Xcode project wired to the framework.

### What's Supacode-Specific (to strip/replace)

- **TCA (Composable Architecture)** — Heavy dependency for state management. Supacode uses it for `AppFeature`, `RepositoriesFeature`, `SettingsFeature`, etc. For a simpler app, plain `@Observable` is sufficient.
- **Worktree-centric data model** — Supacode manages git worktrees with `Repository` → `Worktree` hierarchy, `GitClient` wrapping `git-wt`, `WorktreeInfoWatcherManager`, GitHub PR integration, etc. We need a simpler **project → worktrees → sessions** model.
- **`WorktreeTerminalManager` / `WorktreeTerminalState`** — These manage per-worktree tab groups with split trees. Much of this machinery (split panes, tab reordering, drag-drop between splits, run scripts) is overkill for the pi app.
- **GitHub/PR integration, analytics (PostHog), crash reporting (Sentry), auto-updates (Sparkle)** — Not needed initially.
- **Custom tab bar UI** — 80+ files for terminal tab bar rendering. We can use a simpler approach.

### Recommendation: **Start a new project, port the Ghostty infrastructure layer**

The ghostty layer (6 files, ~1500 lines total) is clean, well-isolated, and directly portable. Everything above it is supacode-specific. Starting fresh avoids dealing with TCA removal, 186 Swift files of unwanted features, and the complex Xcode project configuration.

---

## 2. Architecture Overview

```
PiDesktop.app
├─ App Layer
│   ├─ PiDesktopApp.swift          (SwiftUI App entry, ghostty init)
│   └─ MainWindow.swift            (NavigationSplitView: sidebar + detail)
│
├─ Ghostty Infrastructure (ported from supacode, ~6 files)
│   ├─ GhosttyRuntime.swift        (singleton, app lifecycle)
│   ├─ GhosttySurfaceView.swift    (NSView, input handling)
│   ├─ GhosttySurfaceBridge.swift  (action dispatch, notifications)
│   ├─ GhosttySurfaceState.swift   (observable surface state)
│   ├─ GhosttyTerminalView.swift   (SwiftUI wrapper)
│   ├─ GhosttySplitAction.swift    (split action enum)
│   ├─ GhosttyShortcutManager.swift
│   └─ SecureInput.swift
│
├─ Models
│   ├─ Project.swift               (registered project: path, name)
│   ├─ ProjectWorktree.swift       (worktree: path, branch, diff stats)
│   ├─ PiSession.swift             (session file metadata, status)
│   └─ SessionStatus.swift         (running/idle/stopped)
│
├─ Services
│   ├─ ProjectStore.swift          (@Observable, persisted project list)
│   ├─ GitService.swift            (worktree listing, diff stats)
│   ├─ SessionScanner.swift        (scan ~/.pi/agent/sessions/ for project sessions)
│   ├─ ProcessMonitor.swift        (check if pi process is alive + idle detection)
│   └─ FileWatcher.swift           (FSEvents for session/worktree changes)
│
├─ Features
│   ├─ Sidebar
│   │   ├─ SidebarView.swift       (project list with worktrees)
│   │   ├─ ProjectSectionView.swift
│   │   ├─ WorktreeRowView.swift   (+/- diff, session status indicator)
│   │   └─ AddProjectView.swift
│   │
│   ├─ Terminal
│   │   ├─ TerminalTabManager.swift (@Observable, tab list for detail pane)
│   │   ├─ TerminalTab.swift        (model: id, title, type, surface)
│   │   ├─ TerminalTabBarView.swift
│   │   └─ TerminalDetailView.swift (selected tab's terminal surface)
│   │
│   └─ Settings
│       └─ SettingsView.swift       (project management, theme, keybinds)
│
├─ Theme
│   └─ RosePineTheme.swift          (color constants for UI chrome)
│
├─ Resources
│   ├─ ghostty/                     (ghostty resources from build)
│   └─ terminfo/
│
├─ ThirdParty/ghostty               (git submodule)
└─ Frameworks/GhosttyKit.xcframework
```

---

## 3. Detailed Implementation Plan

### Phase 0: Project Scaffolding ✅

1. **Create new Xcode project** `PiDesktop` (macOS App, SwiftUI lifecycle, Swift 6.2, macOS 15.0+ deployment target)
2. **Add ghostty submodule**: `git submodule add https://github.com/ghostty-org/ghostty ThirdParty/ghostty`
3. **Port Makefile** from supacode for `build-ghostty-xcframework` target
4. **Link `GhosttyKit.xcframework`** and `Carbon.framework` in Xcode project
5. **Set `GHOSTTY_RESOURCES_DIR`** env in app startup (same as supacode)
6. **Configure `mise.toml`** for zig toolchain

### Phase 1: Ghostty Infrastructure (port from supacode) ✅

Port these files **verbatim** from supacode, removing only supacode-specific imports:

| File | Changes from supacode |
|---|---|
| `GhosttyRuntime.swift` | Remove Sentry/PostHog. Keep as-is. |
| `GhosttySurfaceView.swift` | Keep entirely. This is the core. |
| `GhosttySurfaceBridge.swift` | Keep entirely. Notifications come through here. |
| `GhosttySurfaceState.swift` | Keep as-is. |
| `GhosttyTerminalView.swift` | Keep as-is (NSViewRepresentable wrapper). |
| `GhosttySplitAction.swift` | Keep as-is. |
| `GhosttyShortcutManager.swift` | Keep as-is. |
| `SecureInput.swift` | Keep as-is. |

**Validation**: Build a minimal app that shows a single `GhosttyTerminalView` running `zsh`. Verify input, scrolling, clipboard, color scheme sync all work.

### Phase 2: Terminal Tab Management ✅

Create a simplified version of supacode's tab system (no splits, no TCA):

```swift
@MainActor @Observable
final class TerminalTabManager {
  var tabs: [TerminalTab] = []
  var selectedTabID: UUID?

  func createPiTab(workingDirectory: URL, worktreeName: String) -> UUID
  func createLazygitTab(workingDirectory: URL) -> UUID
  func createLumenDiffTab(workingDirectory: URL) -> UUID
  func createShellTab(workingDirectory: URL) -> UUID
  func closeTab(_ id: UUID)
  func selectTab(_ id: UUID)
}
```

Each `TerminalTab` holds:
```swift
struct TerminalTab: Identifiable {
  let id: UUID
  let type: TabType  // .pi, .lazygit, .lumenDiff, .shell
  var title: String
  let surfaceView: GhosttySurfaceView
  var hasNotification: Bool
  var isRunning: Bool  // from progress report state
}
```

**Tab spawning**: Create `GhosttySurfaceView` with:
- `workingDirectory`: the worktree path
- `initialInput`: the command to run, e.g.:
  - Pi: `"pi\n"` (or `"pi -c\n"` to continue)
  - Lazygit: `"lazygit\n"`
  - Lumen diff: `"lumen diff\n"` (or whatever the command is)

**Close-on-exit**: Wire `bridge.onCloseRequest` to automatically remove the tab when the shell process exits (pi exits → shell exits → ghostty fires `close_surface`). This is already how supacode handles it via `handleCloseRequest`.

### Phase 3: OSC 777 Notifications ✅

Already handled by the ported `GhosttySurfaceBridge`. The `GHOSTTY_ACTION_DESKTOP_NOTIFICATION` action fires `onDesktopNotification` callback with title and body.

Wire it to:
1. **macOS `UNUserNotificationCenter`** for system notifications
2. **Tab badge/indicator** in the tab bar
3. **Sidebar indicator** on the worktree row

Pi extensions that call `ctx.ui.notify()` will trigger these via the terminal's OSC 777 sequence (ghostty supports this natively).

### Phase 4: Side Panel — Project Registry

**`ProjectStore`** (`@Observable`, persisted to `UserDefaults` or a JSON file):

```swift
@MainActor @Observable
final class ProjectStore {
  var projects: [Project] = []  // persisted

  func addProject(path: URL)
  func removeProject(_ id: Project.ID)
  func refresh()  // re-scan worktrees + sessions for all projects
}
```

**`Project`** model:
```swift
struct Project: Identifiable, Codable {
  let id: UUID
  let rootPath: URL
  var name: String  // derived from folder name
  var worktrees: [ProjectWorktree]  // populated by scanning
}
```

**`ProjectWorktree`** model:
```swift
struct ProjectWorktree: Identifiable {
  let id: String  // worktree path
  let name: String  // branch name
  let path: URL
  var addedLines: Int?
  var removedLines: Int?
  var sessions: [PiSessionInfo]
  var sessionStatus: SessionStatus  // .running, .idle, .stopped
}
```

### Phase 5: Worktree & Session Discovery

**Git worktree scanning** (simplified from supacode's `GitClient`):
- Run `git worktree list --porcelain` in project root
- Parse output to get worktree paths and branch names
- Run `git diff HEAD --shortstat` in each worktree for +/- stats

**Pi session scanning**:
- Map project path to session directory: `~/.pi/agent/sessions/--<path-with-dashes>--/`
- List `.jsonl` files, parse headers for timestamp/metadata
- For worktree paths, check both main repo and `.worktrees/<name>` session dirs

**Idle detection**:
- **Process-based**: Check if a `pi` or `node` process is running with the worktree as cwd (via `ps aux` or `proc_pidinfo`)
- **Progress report-based**: The ghostty bridge already tracks `progressState`. If a pi tab is open and its `progressState` is nil/removed, it's idle. If it's `SET`/`INDETERMINATE`, it's running.
- **Combination**: For tabs open in our app, use progress reports. For external sessions (opened in another terminal), use process scanning.

**Polling**: Use a `Timer` or `DispatchSource` with FSEvents to watch:
- Worktree directories for git changes (refresh diff stats)
- `~/.pi/agent/sessions/` for new/modified session files

### Phase 6: Sidebar UI

```
┌─────────────────────────┐
│ 🔍 Search Projects      │
├─────────────────────────┤
│ ▼ anvil                 │
│   ● main        +12 -3  │  ← green dot = running
│   ◐ feature-x   +45 -8  │  ← half dot = idle
│   ○ bugfix-y    +2  -1  │  ← empty dot = stopped
│                         │
│ ▼ my-other-project      │
│   ● main        +0  -0  │
│                         │
│ + Add Project           │
└─────────────────────────┘
```

**Status indicators**:
- 🟢 (filled circle, green) — pi session running and actively processing
- 🟡 (filled circle, yellow) — pi session running but idle (waiting for input)
- ⚪ (empty circle, gray) — no active session

**Clicking a worktree row**:
- Selects it in the detail pane
- If a pi tab exists for it, switches to it
- If not, shows an empty state with a "Start pi session" button

### Phase 7: Keybindings

These must not collide with ghostty defaults or pi keybindings.

**Ghostty defaults use**: `Cmd+T` (new tab), `Cmd+W` (close), `Cmd+N` (new window), `Cmd+1-9` (switch tab), `Cmd+Shift+]`/`[` (next/prev tab), `Cmd+D`/`Cmd+Shift+D` (split).

**Pi keybindings use**: `Ctrl+P` (model picker), `Ctrl+L` (clear), `Ctrl+C` (cancel), `Ctrl+D` (exit), `Esc` (various), arrow keys, etc.

**Proposed app keybindings** (using `Cmd+Ctrl` and `Cmd+Shift` combos):

| Action | Keybinding | Rationale |
|--------|-----------|-----------|
| New pi session tab | `Cmd+Shift+N` | Avoids Cmd+T (ghostty), Cmd+N (new window) |
| Close tab | `Cmd+Shift+W` | Avoids Cmd+W (ghostty close surface) |
| Open lazygit | `Cmd+Ctrl+G` | G for git |
| Open lumen diff | `Cmd+Ctrl+D` | D for diff |
| Open in terminal (Ghostty) | `Cmd+Ctrl+T` | T for terminal |
| Open in Zed | `Cmd+Ctrl+Z` | Z for Zed |
| Toggle sidebar | `Cmd+Ctrl+S` | S for sidebar |
| Next tab | `Cmd+Ctrl+]` | Matches bracket convention |
| Previous tab | `Cmd+Ctrl+[` | Matches bracket convention |
| Switch to tab 1-9 | `Cmd+Ctrl+1-9` | Avoids Cmd+1-9 (ghostty) |
| Settings | `Cmd+,` | Standard macOS |
| Focus sidebar | `Cmd+Ctrl+0` | 0 for sidebar focus |

These are **unbound from ghostty** at init time (same pattern as supacode's `AppShortcuts.all` → `--keybind=<bind>=unbind`).

### Phase 8: Open in External App

**Open in Ghostty terminal**:
```swift
// Use AppleScript or `open` command to open in Ghostty
func openInGhostty(path: URL) {
  let script = "tell application \"Ghostty\" to activate"
  // Or: NSWorkspace.shared.open with Ghostty bundle ID
  // Then use ghostty CLI: ghostty --working-directory=<path>
}
```

**Open in Zed**:
```swift
func openInZed(path: URL) {
  Process.launchedProcess(
    launchPath: "/usr/bin/env",
    arguments: ["zed", path.path]
  )
}
```

Both exposed as toolbar buttons + the keybindings above.

### Phase 9: Rosé Pine Theme

Implement as a Swift color palette used for all app chrome (sidebar, tab bar, backgrounds):

```swift
enum RosePine {
  // Base
  static let base = Color(hex: "#191724")
  static let surface = Color(hex: "#1f1d2e")
  static let overlay = Color(hex: "#26233a")
  static let muted = Color(hex: "#6e6a86")
  static let subtle = Color(hex: "#908caa")
  static let text = Color(hex: "#e0def4")
  // Accent
  static let love = Color(hex: "#eb6f92")   // red/errors
  static let gold = Color(hex: "#f6c177")   // warnings/idle
  static let rose = Color(hex: "#ebbcba")   // primary accent
  static let pine = Color(hex: "#31748f")   // info
  static let foam = Color(hex: "#9ccfd8")   // links
  static let iris = Color(hex: "#c4a7e7")   // highlight
  // For diff
  static let added = Color(hex: "#9ccfd8")  // foam for +
  static let removed = Color(hex: "#eb6f92") // love for -
}
```

The terminal itself will use whatever ghostty theme the user has configured (presumably also rosé pine via `~/.config/ghostty/config`). The app chrome matches.

### Phase 10: Pi Session Integration Details

**Spawning pi in a tab**:
```swift
// initialInput for GhosttySurfaceView
let piCommand = "pi\n"  // fresh session
// or: "pi -c\n"  // continue previous
// or: "pi --session <path>\n"  // resume specific
```

**Close behavior**: When pi exits (user types `/exit` or Ctrl+D), the shell exits, ghostty fires `close_surface_cb` → `bridge.onCloseRequest` → tab is removed. No zombie tabs.

**Pi extensions**: Work automatically because pi runs in a real terminal. The ghostty surface provides full VT100/xterm compatibility. Extensions that use `ctx.ui.custom()`, `ctx.ui.select()`, etc. all render through the terminal.

---

## 4. Dependency List

| Dependency | Purpose | Required? |
|-----------|---------|-----------|
| GhosttyKit (xcframework) | Terminal emulation | Yes |
| Carbon.framework | Keyboard layout detection | Yes |
| swift-dependencies | No (use plain DI) | No |
| TCA | No (use @Observable) | No |
| Sparkle | Auto-updates (defer) | Later |
| PostHog/Sentry | Analytics/crashes (defer) | Later |

The app should have **zero Swift package dependencies** initially. Pure SwiftUI + AppKit + GhosttyKit.

---

## 5. File Count Estimate

| Layer | Files | Lines (est.) |
|-------|-------|-------------|
| Ghostty infrastructure (ported) | 8 | ~1500 |
| Models | 4 | ~150 |
| Services | 5 | ~400 |
| Sidebar views | 4 | ~400 |
| Terminal views | 4 | ~350 |
| App/Settings | 3 | ~200 |
| Theme | 1 | ~50 |
| **Total** | **~29** | **~3050** |

vs. supacode's 186 files. This is a **6x reduction** in complexity.

---

## 6. Phased Delivery

| Phase | Milestone | Est. Effort |
|-------|----------|------------|
| 0-1 | Terminal renders, pi launches in a surface | 1-2 days |
| 2-3 | Tab management, notifications work | 1 day |
| 4-5 | Project registry, worktree/session scanning | 1-2 days |
| 6 | Sidebar UI with status indicators | 1 day |
| 7-8 | Keybindings, external app integration | 0.5 day |
| 9-10 | Rosé Pine theme, pi session integration polish | 0.5 day |
| **Total** | **MVP** | **~5-7 days** |

---

## 7. Key Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Start fresh vs. modify supacode | **New project** | 90% of supacode is irrelevant; porting 8 ghostty files is trivial |
| State management | **@Observable** | No need for TCA's complexity; single-window app with simple state |
| Session idle detection | **Progress reports (in-app) + process scan (external)** | Progress reports are already wired in the bridge |
| Tab type | **Enum: pi / lazygit / lumenDiff / shell** | Simple, extensible |
| Theme | **Rosé Pine hardcoded** | Per spec; can add theme switching later |
| SPM dependencies | **None initially** | Keep it simple; only GhosttyKit xcframework |