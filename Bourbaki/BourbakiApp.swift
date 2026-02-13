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
    alert.messageText = "Quit Bourbaki?"
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
    let executable = CommandLine.arguments.first ?? "Bourbaki"
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
struct BourbakiApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var ghostty: GhosttyRuntime
  @State private var tabManager: TerminalTabManager
  @State private var projectStore: ProjectStore
  @State private var recentStore: RecentWorktreeStore
  @State private var toolSettings: ToolSettings

  @MainActor init() {
    NSWindow.allowsAutomaticWindowTabbing = false
    JetBrainsMono.registerFonts()

    // Point ghostty at bundled resources
    if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ghostty") {
      setenv("GHOSTTY_RESOURCES_DIR", resourceURL.path, 1)
    }

    // Initialize ghostty with unbind args for app-level keybindings
    GhosttyCLI.argv.withUnsafeBufferPointer { buffer in
      let argc = UInt(max(0, buffer.count - 1))  // exclude nil terminator
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

    let recent = RecentWorktreeStore()
    _recentStore = State(initialValue: recent)
    manager.recentWorktreeStore = recent

    let settings = ToolSettings()
    _toolSettings = State(initialValue: settings)
    manager.toolSettings = settings

    // Check tool availability at startup
    settings.checkToolAvailability()

    // Wire tab manager to app delegate for quit/close confirmation
    appDelegate.tabManager = manager
  }

  var body: some Scene {
    Window("Bourbaki", id: "main") {
      GhosttyColorSchemeSyncView(ghostty: ghostty) {
        MainContentView(
          tabManager: tabManager, projectStore: projectStore, recentStore: recentStore, toolSettings: toolSettings)
      }
    }
    Settings {
      SettingsView(toolSettings: toolSettings)
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

        Button("Open Agent") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .agent, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openAgent.keyEquivalent,
          modifiers: AppShortcuts.openAgent.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open Git") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .git, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openGit.keyEquivalent,
          modifiers: AppShortcuts.openGit.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open Diff") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          tabManager.createTab(type: .diff, workingDirectory: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openDiff.keyEquivalent,
          modifiers: AppShortcuts.openDiff.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        Button("Open in Editor") {
          guard let dir = tabManager.selectedWorktreePath else { return }
          ExternalAppLauncher.openInEditor(path: dir)
        }
        .keyboardShortcut(
          AppShortcuts.openInEditor.keyEquivalent,
          modifiers: AppShortcuts.openInEditor.modifiers
        )
        .disabled(tabManager.selectedWorktreePath == nil)

        // Note: Cmd+W "Close" is handled by the system menu item.
        // MainWindowCloseInterceptor installs a delegate on the main window
        // that closes a tab instead of the window. For other windows (e.g.
        // Settings), the system Close works normally.

        Divider()

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

        ForEach(Array(AppShortcuts.worktreeShortcuts.enumerated()), id: \.offset) { index, shortcut in
          Button("Worktree \(index + 1)") {
            tabManager.selectWorktreeByIndex(index)
          }
          .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
        }

        Divider()

        ForEach(Array(AppShortcuts.tabShortcuts.enumerated()), id: \.offset) { index, shortcut in
          Button("Tab \(index + 1)") {
            if tabManager.selectedWorktreePath == nil {
              // Dashboard mode: open recent worktree by index
              let entries = recentStore.entries
              if index < entries.count, let url = recentStore.url(for: entries[index]) {
                tabManager.selectWorktree(url)
              }
            } else {
              tabManager.selectTabByIndex(index)
            }
          }
          .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
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
  static func openInEditor(path: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", "Zed", path.path]
    try? process.run()
  }
}

// MARK: - Main Window Close Interceptor

/// Installs an NSWindowDelegate on the hosting window so that Cmd+W (system "Close")
/// closes a tab instead of the window. For non-main windows (e.g. Settings) the system
/// Close works normally — only this window's close is intercepted.
private struct MainWindowCloseInterceptor: NSViewRepresentable {
  let tabManager: TerminalTabManager

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    // Delay to ensure the view is installed in the window
    DispatchQueue.main.async {
      guard let window = view.window else { return }
      context.coordinator.install(on: window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(tabManager: tabManager)
  }

  final class Coordinator: NSObject, NSWindowDelegate {
    let tabManager: TerminalTabManager
    private weak var installedWindow: NSWindow?

    init(tabManager: TerminalTabManager) {
      self.tabManager = tabManager
    }

    func install(on window: NSWindow) {
      guard installedWindow == nil else { return }
      installedWindow = window
      window.delegate = self
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
      MainActor.assumeIsolated {
        if let id = tabManager.selectedTabID {
          // Close the selected tab instead of the window.
          tabManager.closeTab(id)
          return
        }
        // No tabs open — quit the app.
        NSApp.terminate(nil)
      }
      return false
    }
  }
}

// MARK: - Main Content

private struct MainContentView: View {
  @Bindable var tabManager: TerminalTabManager
  @Bindable var projectStore: ProjectStore
  @Bindable var recentStore: RecentWorktreeStore
  var toolSettings: ToolSettings

  var body: some View {
    NavigationSplitView {
      SidebarView(projectStore: projectStore, tabManager: tabManager)
        .background(RosePine.surface)
    } detail: {
      TerminalDetailView(
        tabManager: tabManager, projectStore: projectStore, recentStore: recentStore, toolSettings: toolSettings)
    }
    .frame(minWidth: 800, minHeight: 500)
    .rosePineWindow()
    .background {
      MainWindowCloseInterceptor(tabManager: tabManager)
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
