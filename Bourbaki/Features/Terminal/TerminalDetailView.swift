import SwiftUI

struct TerminalDetailView: View {
  @Bindable var tabManager: TerminalTabManager
  @Bindable var projectStore: ProjectStore

  var body: some View {
    VStack(spacing: 0) {
      if !tabManager.visibleTabs.isEmpty {
        TerminalTabBarView(tabManager: tabManager)
      }

      ZStack {
        if let tab = tabManager.selectedTab {
          GhosttyTerminalView(surfaceView: tab.surfaceView)
            .id(tab.id)
        } else if tabManager.selectedWorktreePath != nil {
          worktreeEmptyState
        } else {
          noWorktreeState
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(RosePine.base)
    }
    .background(WindowTitleUpdater(title: windowTitle))
  }

  private var windowTitle: String {
    guard let worktreePath = tabManager.selectedWorktreePath else {
      return "Bourbaki"
    }
    let standardized = worktreePath.standardizedFileURL

    for project in projectStore.projects {
      if let worktree = project.worktrees.first(where: {
        $0.path.standardizedFileURL == standardized
      }) {
        return "\(project.name) · \(worktree.name)"
      }
      if project.rootPath.standardizedFileURL == standardized {
        return "\(project.name)"
      }
    }

    return "\(worktreePath.lastPathComponent)"
  }

  private var worktreeEmptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "terminal")
        .font(.jetBrainsMono(size: 48))
        .foregroundStyle(RosePine.muted)
      Text("No tabs open for this worktree")
        .font(.jetBrainsMono(size: 17, weight: .semibold))
        .foregroundStyle(RosePine.subtle)
      Text("Right-click the worktree in the sidebar to open a session")
        .font(.jetBrainsMono(size: 14))
        .foregroundStyle(RosePine.muted)
    }
  }

  private var noWorktreeState: some View {
    VStack(spacing: 12) {
      Image(systemName: "sidebar.left")
        .font(.jetBrainsMono(size: 48))
        .foregroundStyle(RosePine.muted)
      Text("Select a worktree")
        .font(.jetBrainsMono(size: 17, weight: .semibold))
        .foregroundStyle(RosePine.subtle)
      Text("Choose a project worktree from the sidebar")
        .font(.jetBrainsMono(size: 14))
        .foregroundStyle(RosePine.muted)
    }
  }
}

// MARK: - Window Title Updater

/// An invisible NSViewRepresentable that sets the hosting window's title reactively.
private struct WindowTitleUpdater: NSViewRepresentable {
  let title: String

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.frame = .zero
    DispatchQueue.main.async {
      view.window?.title = title
      applyTitleFont(to: view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      nsView.window?.title = title
      applyTitleFont(to: nsView.window)
    }
  }

  private func applyTitleFont(to window: NSWindow?) {
    guard let window,
          let titleFont = NSFont(name: "JetBrainsMonoNF-Medium", size: 13),
          let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview
    else { return }
    applyFont(titleFont, in: titlebarView)
  }

  private func applyFont(_ font: NSFont, in view: NSView) {
    if let textField = view as? NSTextField {
      textField.font = font
    }
    for subview in view.subviews {
      applyFont(font, in: subview)
    }
  }
}
