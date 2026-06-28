import SwiftUI

typealias AppCommandAction = () -> Void

struct AppCommandSet {
    var newWorkspace: AppCommandAction
    var openWorkspace: AppCommandAction
    var saveWorkspace: AppCommandAction
    var saveWorkspaceAs: AppCommandAction
    var chooseImage: AppCommandAction
    var removeSelectedImage: AppCommandAction
    var canRemoveSelectedImage: Bool
}

private struct AppCommandSetKey: FocusedValueKey {
    typealias Value = AppCommandSet
}

extension FocusedValues {
    var appCommandSet: AppCommandSet? {
        get { self[AppCommandSetKey.self] }
        set { self[AppCommandSetKey.self] = newValue }
    }
}
