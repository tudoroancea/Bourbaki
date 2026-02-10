import AppKit
import GhosttyKit
import SwiftUI

@main
@MainActor
struct PiDesktopApp: App {
  @State private var ghostty: GhosttyRuntime
  @State private var tabManager: TerminalTabManager

  @MainActor init() {
    NSWindow.allowsAutomaticWindowTabbing = false

    // Point ghostty at bundled resources
    if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ghostty") {
      setenv("GHOSTTY_RESOURCES_DIR", resourceURL.path, 1)
    }

    // Initialize ghostty with no extra CLI args (just the executable name)
    let argv: [UnsafeMutablePointer<CChar>?] = [strdup(CommandLine.arguments.first ?? "PiDesktop"), nil]
    argv.withUnsafeBufferPointer { buffer in
      let argc = UInt(max(0, buffer.count - 1))
      let ptr = UnsafeMutablePointer(mutating: buffer.baseAddress)
      if ghostty_init(argc, ptr) != GHOSTTY_SUCCESS {
        preconditionFailure("ghostty_init failed")
      }
    }

    let runtime = GhosttyRuntime()
    _ghostty = State(initialValue: runtime)

    let manager = TerminalTabManager(runtime: runtime)
    _tabManager = State(initialValue: manager)

  }

  var body: some Scene {
    Window("PiDesktop", id: "main") {
      GhosttyColorSchemeSyncView(ghostty: ghostty) {
        MainContentView(tabManager: tabManager)
      }
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Shell Tab") {
          let homeURL = FileManager.default.homeDirectoryForCurrentUser
          tabManager.createTab(type: .shell, workingDirectory: homeURL)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Pi Tab") {
          let homeURL = FileManager.default.homeDirectoryForCurrentUser
          tabManager.createTab(type: .pi, workingDirectory: homeURL)
        }
        .keyboardShortcut("n", modifiers: [.command, .control])

        Divider()

        Button("Close Tab") {
          if let id = tabManager.selectedTabID {
            tabManager.closeTab(id)
          }
        }
        .keyboardShortcut("w", modifiers: [.command, .shift])
        .disabled(tabManager.selectedTabID == nil)
      }

      CommandGroup(after: .toolbar) {
        Button("Next Tab") {
          tabManager.selectNextTab()
        }
        .keyboardShortcut("]", modifiers: [.command, .control])

        Button("Previous Tab") {
          tabManager.selectPreviousTab()
        }
        .keyboardShortcut("[", modifiers: [.command, .control])

        Divider()

        ForEach(0..<9, id: \.self) { index in
          Button("Tab \(index + 1)") {
            tabManager.selectTabByIndex(index)
          }
          .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .control])
        }
      }
    }
  }
}

// MARK: - Main Content

private struct MainContentView: View {
  @Bindable var tabManager: TerminalTabManager

  var body: some View {
    TerminalDetailView(tabManager: tabManager)
      .frame(minWidth: 600, minHeight: 400)
      .onAppear {
        // Create an initial shell tab if none exist
        if tabManager.tabs.isEmpty {
          let homeURL = FileManager.default.homeDirectoryForCurrentUser
          tabManager.createTab(type: .shell, workingDirectory: homeURL)
        }
      }
  }
}

// MARK: - Color Scheme Sync

private struct GhosttyColorSchemeSyncView<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  let ghostty: GhosttyRuntime
  let content: Content

  init(ghostty: GhosttyRuntime, @ViewBuilder content: () -> Content) {
    self.ghostty = ghostty
    self.content = content()
  }

  var body: some View {
    content
      .task {
        apply(colorScheme)
      }
      .onChange(of: colorScheme) { _, newValue in
        apply(newValue)
      }
  }

  private func apply(_ scheme: ColorScheme) {
    ghostty.setColorScheme(scheme)
  }
}
