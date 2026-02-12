import SwiftUI

struct ProjectSectionView: View {
  let project: Project
  @Bindable var tabManager: TerminalTabManager
  @Binding var isExpanded: Bool
  var onRemove: (() -> Void)?
  var onRefresh: (() async -> Void)?

  @State private var showingCreateWorktree = false
  @State private var worktreeToDelete: ProjectWorktree?
  @State private var isHoveringHeader = false

  var body: some View {
    VStack(spacing: 0) {
      // MARK: - Project Header
      HStack {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.jetBrainsMono(size: 10, weight: .semibold))
          .foregroundStyle(RosePine.subtle)
          .frame(width: 12)

        Text(project.name)
          .font(.jetBrainsMono(size: 14, weight: .semibold))
          .foregroundStyle(RosePine.text)

        Spacer()

        if isHoveringHeader {
          Button {
            showingCreateWorktree = true
          } label: {
            Image(systemName: "plus")
              .font(.jetBrainsMono(size: 11))
              .foregroundStyle(RosePine.subtle)
          }
          .buttonStyle(.plain)
          .help("Create a new worktree")
          .padding(.trailing, 4)
        }
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(RosePine.highlightMed, lineWidth: 1)
          .opacity(isHoveringHeader ? 1 : 0)
      )
      .onHover { hovering in
        isHoveringHeader = hovering
      }
      .onTapGesture {
        isExpanded.toggle()
      }
      .contextMenu {
        Button("New Worktree…") {
          showingCreateWorktree = true
        }
        Divider()
        Button("Open in Editor") {
          ExternalAppLauncher.openInEditor(path: project.rootPath)
        }
        Divider()
        Button("Remove Project", role: .destructive) {
          onRemove?()
        }
      }

      // MARK: - Worktree List
      if isExpanded {
        VStack(spacing: 2) {
          if project.worktrees.isEmpty {
            worktreeRow(name: project.name, path: project.rootPath, worktree: nil)
          } else {
            ForEach(project.worktrees) { worktree in
              worktreeRow(name: worktree.name, path: worktree.path, worktree: worktree)
            }
          }
        }
        .padding(.top, 4)
        .padding(.leading, 12)
      }
    }
    .sheet(isPresented: $showingCreateWorktree) {
      CreateWorktreeView(projectRootPath: project.rootPath) {
        Task { await onRefresh?() }
      }
    }
    .sheet(item: $worktreeToDelete) { worktree in
      DeleteWorktreeView(
        projectRootPath: project.rootPath,
        worktree: worktree,
        onDeleted: {
          Task { await onRefresh?() }
        }
      )
    }
  }

  private func worktreeRow(name: String, path: URL, worktree: ProjectWorktree?) -> some View {
    let isSelected = tabManager.selectedWorktreePath?.standardizedFileURL == path.standardizedFileURL
    let status = tabManager.sessionStatus(for: path)

    let isMain = worktree == nil ||
      worktree!.path.standardizedFileURL == project.rootPath.standardizedFileURL
    let canDelete = worktree != nil && !isMain

    return HoverableWorktreeRow(
      name: name,
      addedLines: worktree?.addedLines,
      removedLines: worktree?.removedLines,
      sessionStatus: status,
      isSelected: isSelected,
      isMainWorktree: isMain,
      onDelete: canDelete ? { worktreeToDelete = worktree } : nil,
      onSelect: { tabManager.selectWorktree(path) }
    )
    .contextMenu {
      Button("Open Agent Session") {
        tabManager.createTab(type: .agent, workingDirectory: path)
      }
      Button("Open Git") {
        tabManager.createTab(type: .git, workingDirectory: path)
      }
      Button("Open Diff") {
        tabManager.createTab(type: .diff, workingDirectory: path)
      }
      Button("Open Shell") {
        tabManager.createTab(type: .shell, workingDirectory: path)
      }
      Divider()
      Button("Open in Editor") {
        ExternalAppLauncher.openInEditor(path: path)
      }
      if let worktree, worktree.path.standardizedFileURL != project.rootPath.standardizedFileURL {
        Divider()
        Button("Delete Worktree…", role: .destructive) {
          worktreeToDelete = worktree
        }
      }
    }
  }
}

// MARK: - Hoverable Worktree Row Wrapper

private struct HoverableWorktreeRow: View {
  let name: String
  let addedLines: Int?
  let removedLines: Int?
  let sessionStatus: SessionStatus
  let isSelected: Bool
  var isMainWorktree: Bool = false
  var onDelete: (() -> Void)?
  var onSelect: () -> Void

  @State private var isHovering = false

  var body: some View {
    WorktreeRowView(
      name: name,
      addedLines: addedLines,
      removedLines: removedLines,
      sessionStatus: sessionStatus,
      isMainWorktree: isMainWorktree,
      onDelete: onDelete
    )
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? RosePine.sidebarSelected : Color.clear)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(RosePine.highlightMed, lineWidth: 1)
        .opacity(isHovering && !isSelected ? 1 : 0)
    )
    .contentShape(RoundedRectangle(cornerRadius: 8))
    .onHover { hovering in
      isHovering = hovering
    }
    .onTapGesture {
      onSelect()
    }
  }
}
