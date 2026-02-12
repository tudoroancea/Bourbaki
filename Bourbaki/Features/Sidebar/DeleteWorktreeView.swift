import SwiftUI

/// A confirmation sheet for deleting a git worktree.
struct DeleteWorktreeView: View {
  let projectRootPath: URL
  let worktree: ProjectWorktree
  let onDeleted: () -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var hasUncommittedChanges: Bool = false
  @State private var forceDelete: Bool = false
  @State private var deleteBranch: Bool = false
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?
  @State private var didCheckChanges: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      // Header
      Text("Delete Worktree")
        .font(.jetBrainsMono(size: 17, weight: .semibold))
        .foregroundStyle(RosePine.text)
        .padding(.top, 16)
        .padding(.bottom, 12)

      VStack(alignment: .leading, spacing: 12) {
        Text("Are you sure you want to delete the worktree **\(worktree.name)**?")
          .foregroundStyle(RosePine.text)

        if !didCheckChanges {
          ProgressView()
            .controlSize(.small)
        } else {
          if hasUncommittedChanges {
            HStack(spacing: 6) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
              Text("This worktree has uncommitted changes.")
                .foregroundStyle(RosePine.subtle)
            }
            .font(.jetBrainsMono(size: 13))

            Toggle("Discard uncommitted changes", isOn: $forceDelete)
          }

          Toggle("Also delete the associated branch", isOn: $deleteBranch)
        }
      }
      .padding(.horizontal, 20)

      if let errorMessage {
        Text(errorMessage)
          .font(.jetBrainsMono(size: 11))
          .foregroundStyle(.red)
          .padding(.horizontal, 20)
          .padding(.top, 8)
      }

      // Buttons
      HStack {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Delete", role: .destructive) {
          Task { await deleteWorktree() }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!didCheckChanges || (hasUncommittedChanges && !forceDelete) || isLoading)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
      .padding(.top, 16)
    }
    .frame(width: 400)
    .task {
      hasUncommittedChanges = await GitService.hasUncommittedChanges(at: worktree.path)
      didCheckChanges = true
    }
  }

  private func deleteWorktree() async {
    isLoading = true
    errorMessage = nil

    let result = await GitService.deleteWorktree(
      rootPath: projectRootPath,
      worktreePath: worktree.path,
      force: forceDelete,
      deleteBranch: deleteBranch
    )

    isLoading = false

    switch result {
    case .success:
      onDeleted()
      dismiss()
    case .failure(let error):
      errorMessage = error.localizedDescription
    }
  }
}
