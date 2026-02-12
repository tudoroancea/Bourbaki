import SwiftUI

struct SidebarView: View {
  @Bindable var projectStore: ProjectStore
  @Bindable var tabManager: TerminalTabManager
  @State private var searchText = ""
  @State private var showingAddProject = false
  @State private var collapsedProjects: Set<UUID> = []

  var body: some View {
    List {
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
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .listRowBackground(Color.clear)
      }
      .onMove { source, destination in
        projectStore.moveProject(from: source, to: destination)
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
    .background(RosePine.surface)
    .searchable(text: $searchText, placement: .sidebar, prompt: "Search Projects")
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
