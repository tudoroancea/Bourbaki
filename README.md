# Bourbaki

A macOS-native desktop app for managing [pi](https://github.com/mariozechner/pi-coding-agent) coding agent sessions across multiple projects and git worktrees.

> **⚠️ This is a personal tool.** It is built for my specific workflow, taste, and machine (macOS Tahoe). It may not suit yours. You're welcome to fork and adapt it.

![macOS](https://img.shields.io/badge/macOS-26.0%2B-black)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## Why "Bourbaki"?

[Nicolas Bourbaki](https://en.wikipedia.org/wiki/Nicolas_Bourbaki) was the collective pseudonym of a group of mathematicians who published foundational works under a single shared name. No individual credit — the work spoke for itself.

This app embodies the same idea: a single interface commanding an army of anonymous AI agents — Claude, GPT, whatever comes next — all working toward the same cause without taking credit. The agents are interchangeable; what matters is the code they produce together.

## What it does

Bourbaki gives you a single window to manage all your pi sessions, with:

- **Project sidebar** — register local repos, see their git worktrees with live `+/-` diff stats and session status indicators (running / idle / stopped)
- **Tabbed terminal panes** — each tab is a full terminal (powered by [Ghostty](https://ghostty.org)'s `libghostty`) running one of:
  - A **pi** coding agent session
  - A **[lazygit](https://github.com/jesseduffield/lazygit)** instance
  - A plain **shell**
- **Desktop notifications** — pi's `ctx.ui.notify()` triggers macOS notifications via OSC 777
- **Quick-open in external apps** — jump to [Zed](https://zed.dev), [Ghostty](https://ghostty.org), or Finder from any worktree
- **[Rosé Pine](https://rosepinetheme.com)** theme — dark (Rosé Pine) and light (Rosé Pine Dawn), auto-switching with system appearance

## Built with

| Component | Role |
|---|---|
| [Ghostty](https://ghostty.org) (`libghostty`) | Terminal emulation — built from source as a static xcframework |
| [pi](https://github.com/mariozechner/pi-coding-agent) | AI coding agent that runs inside the terminal tabs |
| [lazygit](https://github.com/jesseduffield/lazygit) | Git TUI, launched in dedicated tabs |
| [Zed](https://zed.dev) | Code editor, opened via quick-open |
| SwiftUI + AppKit | UI framework (no third-party Swift dependencies) |

## Building

### Prerequisites

- macOS 26.0+ (Tahoe)
- Xcode (with Metal Toolchain — run `xcodebuild -downloadComponent MetalToolchain` if needed)
- `xcode-select` pointing to `Xcode.app` (not CommandLineTools)
- [mise](https://mise.jdx.dev) (provides zig 0.15.2 for building ghostty)

### Steps

```bash
# Clone with submodules
git clone --recursive git@github.com:tudoroancea/Bourbaki.git
cd Bourbaki

# Build GhosttyKit from source (~5 min first time)
make build-ghostty-xcframework

# Build and run the app
make run-app
```

### Other targets

```bash
make build-app    # build only (Debug)
make check        # format + lint
make help         # list all targets
```

## Keybindings

All app-level keybindings use `Cmd+Ctrl` or `Cmd+Shift` combos to avoid collisions with ghostty defaults and pi's own keybindings.

| Action | Keybinding |
|---|---|
| New pi session | `Cmd+Shift+N` |
| Close tab | `Cmd+Shift+W` |
| Open lazygit | `Cmd+Ctrl+G` |
| Open shell | `Cmd+Ctrl+T` |
| Open in Zed | `Cmd+Ctrl+Z` |
| Toggle sidebar | `Cmd+Ctrl+S` |
| Next / previous tab | `Cmd+Ctrl+]` / `[` |
| Switch to tab 1–9 | `Cmd+Ctrl+1–9` |

## Roadmap

- [x] Make the tab bar more native (closer to Ghostty's tab bar style)
- [x] Show active worktree name/path in the title bar
- [x] Keybindings to switch between active worktrees
- [x] Periodically reload the worktree list and git diff stats in the background
- [x] Worktree management: create and delete worktrees (from existing branch, or with new branch)

## License

[MIT](LICENSE)
