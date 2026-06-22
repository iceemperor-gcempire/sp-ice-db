import SwiftUI
import SpIceDBAppModel

@main
struct SpIceDBApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 1080, minHeight: 640)
                .onAppear {
                    AppIconInstaller.install()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Workspace") {
                    model.newWorkspace()
                }
                .keyboardShortcut("n")
            }

            CommandMenu("Image") {
                Button("Remove Selected Image From Workspace") {
                    model.removeSelectedImage()
                }
                .keyboardShortcut(.delete)
                .disabled(model.selectedImageID == nil)
            }
        }
    }
}
