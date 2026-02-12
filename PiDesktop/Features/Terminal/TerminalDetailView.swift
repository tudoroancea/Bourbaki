import SwiftUI

struct TerminalDetailView: View {
  @Bindable var tabManager: TerminalTabManager

  var body: some View {
    VStack(spacing: 0) {
      if !tabManager.visibleTabs.isEmpty {
        TerminalTabBarView(tabManager: tabManager)
        Divider()
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
    }
  }

  private var worktreeEmptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "terminal")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
      Text("No tabs open for this worktree")
        .font(.headline)
        .foregroundStyle(.secondary)
      Text("Right-click the worktree in the sidebar to open a session")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
    }
  }

  private var noWorktreeState: some View {
    VStack(spacing: 12) {
      Image(systemName: "sidebar.left")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
      Text("Select a worktree")
        .font(.headline)
        .foregroundStyle(.secondary)
      Text("Choose a project worktree from the sidebar")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
    }
  }
}
