import SwiftUI

struct TerminalDetailView: View {
  @Bindable var tabManager: TerminalTabManager

  var body: some View {
    VStack(spacing: 0) {
      if !tabManager.tabs.isEmpty {
        TerminalTabBarView(tabManager: tabManager)
        Divider()
      }

      ZStack {
        if let tab = tabManager.selectedTab {
          GhosttyTerminalView(surfaceView: tab.surfaceView)
            .id(tab.id)
        } else {
          emptyState
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "terminal")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
      Text("No terminal tabs open")
        .font(.headline)
        .foregroundStyle(.secondary)
      Text("Create a new tab to get started")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
    }
  }
}
