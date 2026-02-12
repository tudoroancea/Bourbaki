import SwiftUI

/// A sheet for creating a new git worktree.
struct CreateWorktreeView: View {
  let projectRootPath: URL
  let onCreated: () -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var branches: [String] = []
  @State private var selectedBranch: String = ""
  @State private var worktreeName: String = ""
  @State private var createNewBranch: Bool = true
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      // Header
      Text("New Worktree")
        .font(.jetBrainsMono(size: 17, weight: .semibold))
        .foregroundStyle(RosePine.text)
        .padding(.top, 16)
        .padding(.bottom, 12)

      Form {
        Picker("Base branch", selection: $selectedBranch) {
          ForEach(branches, id: \.self) { branch in
            Text(branch).tag(branch)
          }
        }

        TextField("Worktree name", text: $worktreeName)
          .textFieldStyle(.roundedBorder)

        Toggle("Create new branch", isOn: $createNewBranch)
          .help("If enabled, creates a new branch with the worktree name. Otherwise checks out the base branch.")
      }
      .formStyle(.grouped)
      .scrollDisabled(true)

      if let errorMessage {
        Text(errorMessage)
          .font(.jetBrainsMono(size: 11))
          .foregroundStyle(.red)
          .padding(.horizontal, 20)
          .padding(.bottom, 8)
      }

      // Buttons
      HStack {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Create") {
          Task { await createWorktree() }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(worktreeName.trimmingCharacters(in: .whitespaces).isEmpty || selectedBranch.isEmpty || isLoading)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
      .padding(.top, 8)
    }
    .frame(width: 380)
    .task {
      branches = await GitService.listBranches(for: projectRootPath)
      if let first = branches.first {
        // Default to main/master if available, otherwise first
        selectedBranch = branches.first(where: { $0 == "main" })
          ?? branches.first(where: { $0 == "master" })
          ?? first
      }
    }
  }

  private func createWorktree() async {
    let name = worktreeName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }

    isLoading = true
    errorMessage = nil

    let result = await GitService.createWorktree(
      rootPath: projectRootPath,
      worktreeName: name,
      baseBranch: selectedBranch,
      createBranch: createNewBranch
    )

    isLoading = false

    switch result {
    case .success:
      onCreated()
      dismiss()
    case .failure(let error):
      errorMessage = error.localizedDescription
    }
  }
}
