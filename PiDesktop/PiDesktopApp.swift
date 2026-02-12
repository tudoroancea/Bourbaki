import AppKit
import GhosttyKit
import SwiftUI

@main
@MainActor
struct PiDesktopApp: App {
  @State private var ghostty: GhosttyRuntime
  @State private var tabManager: TerminalTabManager
  @State private var projectStore: ProjectStore

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

    let store = ProjectStore()
    _projectStore = State(initialValue: store)
    manager.projectStore = store
  }

  var body: some Scene {
    Window("PiDesktop", id: "main") {
      GhosttyColorSchemeSyncView(ghostty: ghostty) {
        MainContentView(tabManager: tabManager, projectStore: projectStore)
      }
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Shell Tab") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .shell, workingDirectory: dir)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("New Pi Tab") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .pi, workingDirectory: dir)
        }
        .keyboardShortcut("n", modifiers: [.command, .control])
        .disabled(tabManager.selectedWorktreePath == nil)

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
  @Bindable var projectStore: ProjectStore

  var body: some View {
    NavigationSplitView {
      SidebarView(projectStore: projectStore, tabManager: tabManager)
    } detail: {
      TerminalDetailView(tabManager: tabManager)
    }
    .frame(minWidth: 800, minHeight: 500)

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
