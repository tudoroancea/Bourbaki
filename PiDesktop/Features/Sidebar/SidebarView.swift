import SwiftUI

struct SidebarView: View {
  @Bindable var projectStore: ProjectStore
  @Bindable var tabManager: TerminalTabManager
  @State private var searchText = ""
  @State private var showingAddProject = false

  var body: some View {
    List {
      ForEach(filteredProjects) { project in
        ProjectSectionView(
          project: project,
          tabManager: tabManager,
          onRemove: { projectStore.removeProject(project.id) }
        )
      }
    }
    .listStyle(.sidebar)
    .searchable(text: $searchText, placement: .sidebar, prompt: "Search Projects")
    .navigationTitle("Projects")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        HStack(spacing: 4) {
          Button {
            Task { await projectStore.refresh() }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help("Refresh")

          Button {
            showingAddProject = true
          } label: {
            Image(systemName: "plus")
          }
          .help("Add Project")
        }
      }
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
  }

  private var filteredProjects: [Project] {
    if searchText.isEmpty {
      return projectStore.projects
    }
    return projectStore.projects.filter { project in
      project.name.localizedCaseInsensitiveContains(searchText) ||
      project.worktrees.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
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
