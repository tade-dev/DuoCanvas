import SwiftUI

@main
struct DuoCanvasApp: App {
    private let container = DuoCanvasModelContainer.make(inMemory: false)

    var body: some Scene {
        WindowGroup {
            ProjectListView()
        }
        .modelContainer(container)
    }
}
