import AppKit
import GhosttyKit
import SwiftUI

// MARK: - App Delegate (Cmd+Q confirmation)

final class AppDelegate: NSObject, NSApplicationDelegate {
  /// Set by the SwiftUI app so the delegate can check terminal state.
  var tabManager: TerminalTabManager?

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let tabManager, tabManager.hasRunningTerminals else {
      return .terminateNow
    }

    let alert = NSAlert()
    alert.messageText = "Quit PiDesktop?"
    alert.informativeText = "You still have terminals running. Are you sure you want to quit?"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Quit")
    alert.addButton(withTitle: "Cancel")

    let response = alert.runModal()
    return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
  }
}

/// Builds the argv array for ghostty_init, including unbind args for all app shortcuts.
private enum GhosttyCLI {
  static let argv: [UnsafeMutablePointer<CChar>?] = {
    var args: [UnsafeMutablePointer<CChar>?] = []
    let executable = CommandLine.arguments.first ?? "PiDesktop"
    args.append(strdup(executable))
    for shortcut in AppShortcuts.all {
      args.append(strdup("--keybind=\(shortcut.ghosttyKeybind)=unbind"))
    }
    args.append(nil)
    return args
  }()
}

@main
@MainActor
struct PiDesktopApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var ghostty: GhosttyRuntime
  @State private var tabManager: TerminalTabManager
  @State private var projectStore: ProjectStore

  @MainActor init() {
    NSWindow.allowsAutomaticWindowTabbing = false

    // Point ghostty at bundled resources
    if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ghostty") {
      setenv("GHOSTTY_RESOURCES_DIR", resourceURL.path, 1)
    }

    // Initialize ghostty with unbind args for app-level keybindings
    GhosttyCLI.argv.withUnsafeBufferPointer { buffer in
      let argc = UInt(max(0, buffer.count - 1)) // exclude nil terminator
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

    // Wire tab manager to app delegate for quit/close confirmation
    appDelegate.tabManager = manager
  }

  var body: some Scene {
    Window("PiDesktop", id: "main") {
      GhosttyColorSchemeSyncView(ghostty: ghostty) {
        MainContentView(tabManager: tabManager, projectStore: projectStore)
      }
    }
    .commands {
      // MARK: - File Menu (replacing New Item)
      CommandGroup(replacing: .newItem) {
        Button("New Terminal") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .shell, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.newTerminal.keyEquivalent,
          modifiers: AppShortcuts.newTerminal.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open Pi") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .pi, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openPi.keyEquivalent,
          modifiers: AppShortcuts.openPi.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open Lazygit") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .lazygit, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openLazygit.keyEquivalent,
          modifiers: AppShortcuts.openLazygit.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open Lumen Diff") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .lumenDiff, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openLumenDiff.keyEquivalent,
          modifiers: AppShortcuts.openLumenDiff.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open in Zed") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          ExternalAppLauncher.openInZed(path: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openInZed.keyEquivalent,
          modifiers: AppShortcuts.openInZed.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Divider()

        Button("Close Tab") {
          if let id = tabManager.selectedTabID {
            tabManager.closeTab(id)
          }
        }
        .keyboardShortcut(
          AppShortcuts.closeTab.keyEquivalent,
          modifiers: AppShortcuts.closeTab.modifiers
        )
        .disabled(tabManager.selectedTabID == nil)

        Button("Close Window") {
          NSApp.terminate(nil)
        }
        .keyboardShortcut(
          AppShortcuts.closeWindow.keyEquivalent,
          modifiers: AppShortcuts.closeWindow.modifiers
        )
      }

      // MARK: - View Menu (Tab Navigation + Sidebar)
      CommandGroup(after: .toolbar) {
        Button("Toggle Sidebar") {
          toggleSidebar()
        }
        .keyboardShortcut(
          AppShortcuts.toggleSidebar.keyEquivalent,
          modifiers: AppShortcuts.toggleSidebar.modifiers
        )

        Divider()

        Button("Next Tab") {
          tabManager.selectNextTab()
        }
        .keyboardShortcut(
          AppShortcuts.nextTab.keyEquivalent,
          modifiers: AppShortcuts.nextTab.modifiers
        )

        Button("Previous Tab") {
          tabManager.selectPreviousTab()
        }
        .keyboardShortcut(
          AppShortcuts.previousTab.keyEquivalent,
          modifiers: AppShortcuts.previousTab.modifiers
        )

        Divider()

        ForEach(0..<9, id: \.self) { index in
          Button("Worktree \(index + 1)") {
            tabManager.selectWorktreeByIndex(index)
          }
          .keyboardShortcut(
            KeyEquivalent(Character(String(index + 1))),
            modifiers: [.command]
          )
        }

        Divider()

        ForEach(0..<9, id: \.self) { index in
          Button("Tab \(index + 1)") {
            tabManager.selectTabByIndex(index)
          }
          .keyboardShortcut(
            KeyEquivalent(Character(String(index + 1))),
            modifiers: [.command, .control]
          )
        }

        Button("Focus Sidebar") {
          toggleSidebar()
        }
        .keyboardShortcut(
          AppShortcuts.focusSidebar.keyEquivalent,
          modifiers: AppShortcuts.focusSidebar.modifiers
        )
      }
    }
  }

  private func toggleSidebar() {
    NSApp.keyWindow?.contentViewController?.tryToPerform(
      #selector(NSSplitViewController.toggleSidebar(_:)),
      with: nil
    )
  }
}

// MARK: - External App Launcher

enum ExternalAppLauncher {
  static func openInZed(path: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", "Zed", path.path]
    try? process.run()
  }
}

// MARK: - Main Content

private struct MainContentView: View {
  @Bindable var tabManager: TerminalTabManager
  @Bindable var projectStore: ProjectStore

  var body: some View {
    NavigationSplitView {
      SidebarView(projectStore: projectStore, tabManager: tabManager)
        .background(RosePine.surface)
    } detail: {
      TerminalDetailView(tabManager: tabManager, projectStore: projectStore)
    }
    .frame(minWidth: 800, minHeight: 500)
    .rosePineWindow()
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
