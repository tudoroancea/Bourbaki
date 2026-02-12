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
      return "PiDesktop"
    }
    let standardized = worktreePath.standardizedFileURL

    for project in projectStore.projects {
      if let worktree = project.worktrees.first(where: {
        $0.path.standardizedFileURL == standardized
      }) {
        return "PiDesktop — \(project.name) · \(worktree.name)"
      }
      if project.rootPath.standardizedFileURL == standardized {
        return "PiDesktop — \(project.name)"
      }
    }

    return "PiDesktop — \(worktreePath.lastPathComponent)"
  }

  private var worktreeEmptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "terminal")
        .font(.system(size: 48))
        .foregroundStyle(RosePine.muted)
      Text("No tabs open for this worktree")
        .font(.headline)
        .foregroundStyle(RosePine.subtle)
      Text("Right-click the worktree in the sidebar to open a session")
        .font(.subheadline)
        .foregroundStyle(RosePine.muted)
    }
  }

  private var noWorktreeState: some View {
    VStack(spacing: 12) {
      Image(systemName: "sidebar.left")
        .font(.system(size: 48))
        .foregroundStyle(RosePine.muted)
      Text("Select a worktree")
        .font(.headline)
        .foregroundStyle(RosePine.subtle)
      Text("Choose a project worktree from the sidebar")
        .font(.subheadline)
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
    DispatchQueue.main.async { view.window?.title = title }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async { nsView.window?.title = title }
  }
}
