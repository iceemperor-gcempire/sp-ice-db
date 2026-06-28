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
            SpIceDBCommands()
        }
    }
}
