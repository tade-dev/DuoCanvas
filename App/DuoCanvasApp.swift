import CanvasModel
import SwiftUI
import SwiftData

@main
struct DuoCanvasApp: App {
    private let container: ModelContainer?

    init() {
        do {
            container = try DuoCanvasModelContainer.make(inMemory: false)
        } catch {
            container = nil
            CanvasInstrumentation.log.error("Store open failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ProjectListView()
                    .modelContainer(container)
            } else {
                ContentUnavailableView {
                    Label("Couldn't Open Projects", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(CanvasFailureCopy.storeOpen)
                }
            }
        }
        .commands {
            CanvasEditCommands()
        }
    }
}
