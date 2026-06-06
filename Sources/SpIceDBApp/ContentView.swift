import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpIceDBAppModel
import SpIceDBCore

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var imagePathInput = ""
    @State private var userSentence = ""
    @State private var userTags = ""
    @State private var errorMessage: String?

    private let workspaceContentType = UTType(filenameExtension: "spicedb") ?? .json
    private let imageContentTypes: [UTType] = [.image]

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.newWorkspace()
                    syncEditorFields()
                } label: {
                    Label("New Workspace", systemImage: "doc.badge.plus")
                }

                Button {
                    openWorkspace()
                } label: {
                    Label("Open Workspace", systemImage: "folder")
                }

                Button {
                    saveWorkspace()
                } label: {
                    Label("Save Workspace", systemImage: "square.and.arrow.down")
                }

                Button {
                    addImage()
                } label: {
                    Label("Add Image", systemImage: "photo.badge.plus")
                }

                Button {
                    chooseImageFile()
                } label: {
                    Label("Choose Image", systemImage: "photo")
                }
            }
        }
        .onChange(of: model.selectedImageID) {
            syncEditorFields()
        }
        .alert("sp-ice-db", isPresented: errorPresented) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.workspace.workspace.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if model.hasUnsavedChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Unsaved changes")
                }
            }
            .padding()

            List(selection: $model.selectedImageID) {
                ForEach(model.workspace.images, id: \.id) { image in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(image.displayName ?? image.sourcePath)
                            .lineLimit(1)
                        Text(image.sourcePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(image.id)
                }
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            imagePathBar

            if let image = model.selectedImage {
                metadataEditor(for: image)
            } else {
                ContentUnavailableView(
                    "No Image Selected",
                    systemImage: "photo.on.rectangle",
                    description: Text("Add an image path or select an existing image entry.")
                )
            }
        }
        .padding()
    }

    private var imagePathBar: some View {
        HStack(spacing: 8) {
            TextField("Image file path", text: $imagePathInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addImage)

            Button {
                addImage()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .disabled(imagePathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                chooseImageFile()
            } label: {
                Label("Choose", systemImage: "folder")
            }
        }
    }

    private func metadataEditor(for image: ImageEntry) -> some View {
        Form {
            Section("Image") {
                imagePreview(for: image)
                LabeledContent("Name", value: image.displayName ?? "")
                LabeledContent("Path", value: image.sourcePath)
                LabeledContent("Status", value: selectedImageStatusText)
            }

            Section("User Classification") {
                TextField("Sentence", text: $userSentence, axis: .vertical)
                    .lineLimit(3...6)
                    .onSubmit(saveUserSentence)

                TextField("Tags", text: $userTags)
                    .onSubmit(saveUserTags)

                HStack {
                    Button("Save Sentence") {
                        saveUserSentence()
                    }

                    Button("Save Tags") {
                        saveUserTags()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func imagePreview(for image: ImageEntry) -> some View {
        if model.selectedImageStatus == .readable,
           let nsImage = NSImage(contentsOfFile: image.sourcePath) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ContentUnavailableView(
                selectedImageStatusText,
                systemImage: selectedImageStatusSystemImage
            )
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func addImage() {
        do {
            try model.addImage(path: imagePathInput)
            imagePathInput = ""
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func chooseImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = imageContentTypes
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.message = "Choose image files to add to the workspace."

        guard panel.runModal() == .OK else {
            return
        }

        do {
            for url in panel.urls {
                try model.addImage(path: url.path)
            }
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func openWorkspace() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [workspaceContentType]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "Open a sp-ice-db workspace file."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try model.openWorkspace(from: url)
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func saveWorkspace() {
        if model.workspaceURL == nil {
            saveWorkspaceAs()
            return
        }

        do {
            try model.saveWorkspace()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func saveWorkspaceAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [workspaceContentType]
        panel.nameFieldStringValue = "\(model.workspace.workspace.name).spicedb"
        panel.message = "Save the current sp-ice-db workspace."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try model.saveWorkspace(to: url)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func saveUserSentence() {
        do {
            try model.updateSelectedUserSentence(userSentence)
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func saveUserTags() {
        do {
            try model.updateSelectedUserTags(userTags)
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func syncEditorFields() {
        userSentence = model.selectedImage?.classification.user.sentence ?? ""
        userTags = model.selectedImage?.classification.user.tags.joined(separator: ", ") ?? ""
    }

    private var selectedImageStatusText: String {
        switch model.selectedImageStatus {
        case .readable:
            "Readable"
        case .missing:
            "Missing File"
        case .unreadable:
            "Unreadable File"
        case nil:
            "No Image Selected"
        }
    }

    private var selectedImageStatusSystemImage: String {
        switch model.selectedImageStatus {
        case .readable:
            "photo"
        case .missing:
            "exclamationmark.triangle"
        case .unreadable:
            "lock"
        case nil:
            "photo.on.rectangle"
        }
    }
}
