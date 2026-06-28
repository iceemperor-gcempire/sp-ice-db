import SwiftUI

struct SpIceDBCommands: Commands {
    @FocusedValue(\.appCommandSet) private var commandSet

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workspace") {
                commandSet?.newWorkspace()
            }
            .keyboardShortcut("n")
            .disabled(commandSet == nil)

            Button("Open Workspace...") {
                commandSet?.openWorkspace()
            }
            .keyboardShortcut("o")
            .disabled(commandSet == nil)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Workspace") {
                commandSet?.saveWorkspace()
            }
            .keyboardShortcut("s")
            .disabled(commandSet == nil)

            Button("Save Workspace As...") {
                commandSet?.saveWorkspaceAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(commandSet == nil)
        }

        CommandMenu("Image") {
            Button("Choose Image Files...") {
                commandSet?.chooseImage()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(commandSet == nil)

            Divider()

            Button("Remove Selected Image From Workspace") {
                commandSet?.removeSelectedImage()
            }
            .keyboardShortcut(.delete)
            .disabled(commandSet?.canRemoveSelectedImage != true)
        }
    }
}
