import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
  @Bindable var projectStore: ProjectStore
  @Bindable var tabManager: TerminalTabManager
  @State private var showingAddProject = false
  @State private var collapsedProjects: Set<UUID> = []
  @State private var draggingProjectID: UUID?


  var body: some View {
    ScrollView {
      LazyVStack(spacing: 4) {
        ForEach(filteredProjects) { project in
          ProjectSectionView(
            project: project,
            tabManager: tabManager,
            isExpanded: Binding(
              get: { !collapsedProjects.contains(project.id) },
              set: { newValue in
                if newValue {
                  collapsedProjects.remove(project.id)
                } else {
                  collapsedProjects.insert(project.id)
                }
              }
            ),
            onRemove: { projectStore.removeProject(project.id) },
            onRefresh: { await projectStore.refresh() }
          )
          .onDrag {
            draggingProjectID = project.id
            return NSItemProvider(object: project.id.uuidString as NSString)
          }
          .onDrop(
            of: [.text],
            delegate: ProjectDropDelegate(
              targetProjectID: project.id,
              projectStore: projectStore,
              draggingProjectID: $draggingProjectID
            ))
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 8)
    }
    .background(RosePine.surface)
    .navigationTitle("Projects")
    .safeAreaInset(edge: .bottom) {
      HStack {
        Button {
          Task { await projectStore.refresh() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .help("Refresh all projects")
        .buttonStyle(.borderless)

        Spacer()

        Button {
          showingAddProject = true
        } label: {
          Image(systemName: "plus")
        }
        .help("Add a project folder")
        .buttonStyle(.borderless)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(RosePine.surface)
    }
    .fileImporter(
      isPresented: $showingAddProject,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let url = urls.first {
        projectStore.addProject(path: url)
      }
    }
    .overlay {
      if projectStore.projects.isEmpty {
        emptyState
      }
    }
    .task(id: projectStore.projects.count) {
      await projectStore.refresh()
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(10))
        guard !Task.isCancelled else { break }
        await projectStore.refresh()
      }
    }
  }

  private var filteredProjects: [Project] {
    projectStore.projects
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Projects", systemImage: "folder.badge.plus")
    } description: {
      Text("Add a project folder to get started.")
    } actions: {
      Button("Add Project") {
        showingAddProject = true
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

// MARK: - Drop Delegate

private struct ProjectDropDelegate: DropDelegate {
  let targetProjectID: UUID
  let projectStore: ProjectStore
  @Binding var draggingProjectID: UUID?

  func dropEntered(info: DropInfo) {
    guard let dragging = draggingProjectID, dragging != targetProjectID else { return }
    guard let sourceIndex = projectStore.projects.firstIndex(where: { $0.id == dragging }),
      let destinationIndex = projectStore.projects.firstIndex(where: { $0.id == targetProjectID })
    else { return }

    withAnimation(.easeInOut(duration: 0.2)) {
      projectStore.moveProject(
        from: IndexSet(integer: sourceIndex),
        to: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
      )
    }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggingProjectID = nil
    return true
  }
}
