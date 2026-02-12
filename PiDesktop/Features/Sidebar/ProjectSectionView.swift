import SwiftUI

struct ProjectSectionView: View {
  let project: Project
  @Bindable var tabManager: TerminalTabManager
  var onRemove: (() -> Void)?

  var body: some View {
    Section {
      if project.worktrees.isEmpty {
        worktreeRow(name: project.name, path: project.rootPath, worktree: nil)
      } else {
        ForEach(project.worktrees) { worktree in
          worktreeRow(name: worktree.name, path: worktree.path, worktree: worktree)
        }
      }
    } header: {
      HStack {
        Text(project.name)
        Spacer()
      }
      .contextMenu {
        Button("Open in Ghostty") {
          openInGhostty(path: project.rootPath)
        }
        Button("Open in Zed") {
          openInZed(path: project.rootPath)
        }
        Divider()
        Button("Remove Project", role: .destructive) {
          onRemove?()
        }
      }
    }
  }

  private func worktreeRow(name: String, path: URL, worktree: ProjectWorktree?) -> some View {
    let isSelected = tabManager.selectedWorktreePath?.standardizedFileURL == path.standardizedFileURL
    let status = tabManager.sessionStatus(for: path)

    return Button {
      tabManager.selectWorktree(path)
    } label: {
      WorktreeRowView(
        name: name,
        addedLines: worktree?.addedLines,
        removedLines: worktree?.removedLines,
        sessionStatus: status
      )
    }
    .buttonStyle(.plain)
    .listRowBackground(
      isSelected ? Color.accentColor.opacity(0.2) : Color.clear
    )
    .contextMenu {
      Button("Open Pi Session") {
        tabManager.selectWorktree(path)
        tabManager.createTab(type: .pi, workingDirectory: path)
      }
      Button("Open Lazygit") {
        tabManager.selectWorktree(path)
        tabManager.createTab(type: .lazygit, workingDirectory: path)
      }
      Button("Open Shell") {
        tabManager.selectWorktree(path)
        tabManager.createTab(type: .shell, workingDirectory: path)
      }
      Divider()
      Button("Open in Ghostty") {
        openInGhostty(path: path)
      }
      Button("Open in Zed") {
        openInZed(path: path)
      }
    }
  }

  private func openInGhostty(path: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", "Ghostty", path.path]
    try? process.run()
  }

  private func openInZed(path: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["zed", path.path]
    try? process.run()
  }
}
