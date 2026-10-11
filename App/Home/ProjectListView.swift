import CanvasModel
import PersistenceMapping
import SwiftData
import SwiftUI

/// Home. Create, rename, open, and delete projects. The list is recents: latest `lastOpenedAt` first.
struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [ProjectRecord]

    @State private var path: [UUID] = []
    @State private var namePrompt: NamePrompt?
    @State private var nameText = ""
    @State private var pendingDeleteID: UUID?
    @State private var libraryError: String?
    @Namespace private var projectZoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if orderedProjects.isEmpty {
                ContentUnavailableView {
                    Label(CanvasEmptyCopy.homeTitle, systemImage: "rectangle.on.rectangle")
                } description: {
                    Text(CanvasEmptyCopy.homeMessage)
                } actions: {
                    Button(CanvasEmptyCopy.homeAction) {
                        beginCreate()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: CGFloat(CanvasAccessibility.minimumHitTarget))
                }
                } else {
                    List {
                        Section("Recents") {
                            ForEach(orderedProjects) { project in
                                NavigationLink(value: project.id) {
                                    ProjectRow(project: project)
                                        .matchedTransitionSource(id: project.id, in: projectZoom)
                                }
                                .accessibilityHint("Opens the project.")
                                .accessibilityAction(named: "Rename") {
                                    beginRename(project)
                                }
                                .accessibilityAction(named: "Delete") {
                                    pendingDeleteID = project.id
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        pendingDeleteID = project.id
                                    }
                                }
                                .contextMenu {
                                    Button("Rename") {
                                        beginRename(project)
                                    }
                                    Button("Delete", role: .destructive) {
                                        pendingDeleteID = project.id
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        beginCreate()
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                    .toolbarAccessibility()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ProjectEditorHost(projectID: id)
                    .projectZoomTransition(id: id, in: projectZoom, reduceMotion: reduceMotion)
            }
        }
        .honorReduceMotion()
        .onChange(of: path) { _, newPath in
            guard let id = newPath.last else { return }
            markOpened(id)
        }
        .alert(
            namePrompt?.title ?? "Project",
            isPresented: namePromptIsPresented,
            presenting: namePrompt
        ) { prompt in
            TextField("Name", text: $nameText)
            Button("Cancel", role: .cancel) {}
            Button(prompt.confirmTitle) {
                apply(prompt)
            }
        } message: { prompt in
            Text(prompt.message)
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: deleteIsPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The canvas and its elements will be removed from this device.")
        }
        .alert(
            "Couldn't Update Projects",
            isPresented: libraryErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(libraryError ?? "")
        }
    }

    private var orderedProjects: [ProjectRecord] {
        ProjectListOrdering.recentsFirst(
            Array(projects),
            id: \.id,
            lastOpenedAt: \.lastOpenedAt,
            createdAt: \.createdAt
        )
    }

    private var library: ProjectLibrary {
        ProjectLibrary(context: modelContext)
    }

    private var namePromptIsPresented: Binding<Bool> {
        Binding(
            get: { namePrompt != nil },
            set: { isPresented in
                if !isPresented { namePrompt = nil }
            }
        )
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteID != nil },
            set: { isPresented in
                if !isPresented { pendingDeleteID = nil }
            }
        )
    }

    private var libraryErrorIsPresented: Binding<Bool> {
        Binding(
            get: { libraryError != nil },
            set: { isPresented in
                if !isPresented { libraryError = nil }
            }
        )
    }

    private var deleteTitle: String {
        guard let id = pendingDeleteID, let project = projects.first(where: { $0.id == id }) else {
            return "Delete this project?"
        }
        return "Delete “\(project.name)”?"
    }

    private func beginCreate() {
        nameText = ""
        namePrompt = .create
    }

    private func beginRename(_ project: ProjectRecord) {
        nameText = project.name
        namePrompt = .rename(project.id)
    }

    private func apply(_ prompt: NamePrompt) {
        switch prompt {
        case .create:
            do {
                let id = try library.createProject(name: nameText)
                nameText = ""
                path.append(id)
            } catch {
                reportLibrary(error)
            }
        case .rename(let id):
            guard let project = projects.first(where: { $0.id == id }) else { return }
            do {
                try library.rename(project, to: nameText)
            } catch {
                reportLibrary(error)
            }
        }
    }

    private func markOpened(_ id: UUID) {
        guard let project = projects.first(where: { $0.id == id }) else { return }
        do {
            try library.markOpened(project)
        } catch {
            reportLibrary(error)
        }
    }

    private func confirmDelete() {
        guard let id = pendingDeleteID, let project = projects.first(where: { $0.id == id }) else {
            return
        }
        pendingDeleteID = nil
        path.removeAll { $0 == id }
        do {
            try library.delete(project)
        } catch {
            reportLibrary(error)
        }
    }

    private func reportLibrary(_ error: Error) {
        libraryError = CanvasFailureCopy.libraryUpdate
        CanvasInstrumentation.log.error("Project list update failed: \(error.localizedDescription, privacy: .public)")
    }
}

private struct ProjectRow: View {
    var project: ProjectRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let opened = project.lastOpenedAt {
            return "Opened \(opened.formatted(.relative(presentation: .named)))"
        }
        return "Created \(project.createdAt.formatted(.relative(presentation: .named)))"
    }
}

private enum NamePrompt: Identifiable {
    case create
    case rename(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .rename(let id):
            "rename-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create: "New Project"
        case .rename: "Rename Project"
        }
    }

    var confirmTitle: String {
        switch self {
        case .create: "Create"
        case .rename: "Save"
        }
    }

    var message: String {
        switch self {
        case .create: "The canvas starts empty."
        case .rename: "The new name is shown in Recents."
        }
    }
}

#Preview("Projects") {
    ProjectListView()
        .modelContainer(try! DuoCanvasModelContainer.make(inMemory: true))
}

private extension View {
    @ViewBuilder
    func projectZoomTransition(id: UUID, in namespace: Namespace.ID, reduceMotion: Bool) -> some View {
        if MotionPolicy.usesZoomTransition(reduceMotion: reduceMotion) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
