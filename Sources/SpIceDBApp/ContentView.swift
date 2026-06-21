import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpIceDBAppModel
import SpIceDBCore

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var workspaceNameInput = ""
    @State private var userSentence = ""
    @State private var userTags = ""
    @State private var imageNotes = ""
    @State private var errorMessage: String?

    private let workspaceContentType = UTType(filenameExtension: "spicedb") ?? .json
    private let imageContentTypes: [UTType] = [.image]

    var body: some View {
        mainView
            .frame(minWidth: 1080, minHeight: 640)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        model.newWorkspace()
                        syncWorkspaceFields()
                        syncTaggingFields()
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
                        chooseImageFile()
                    } label: {
                        Label("Choose Image", systemImage: "photo")
                    }

                    Button {
                        removeSelectedImage()
                    } label: {
                        Label("Remove From Workspace", systemImage: "minus.circle")
                    }
                    .disabled(model.selectedImageID == nil)
                }
            }
            .onChange(of: model.selectedImageID) {
                syncTaggingFields()
            }
            .onAppear {
                syncWorkspaceFields()
                syncTaggingFields()
            }
            .alert("sp-ice-db", isPresented: errorPresented) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Workspace name", text: $workspaceNameInput)
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveWorkspaceName)

                Spacer()

                if model.hasUnsavedChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Unsaved changes")
                }
            }
            .padding()

            imageStatusSummary
                .padding(.horizontal)
                .padding(.bottom, 8)

            HSplitView {
                imageListPane
                    .frame(minWidth: 320, idealWidth: 380)

                imagePreviewPane
                    .frame(minWidth: 360, idealWidth: 520, maxWidth: .infinity, maxHeight: .infinity)

                taggingPane
                    .frame(minWidth: 300, idealWidth: 340)
            }
        }
    }

    private var imageListPane: some View {
        VStack(spacing: 0) {
            if model.workspace.images.isEmpty {
                ContentUnavailableView(
                    "No Images",
                    systemImage: "photo.on.rectangle",
                    description: Text("Choose image files to build the workspace list.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                imageList
            }
        }
    }

    private var imagePreviewPane: some View {
        VStack(spacing: 0) {
            previewHeader
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            Group {
                if let image = model.selectedImage {
                    selectedImagePreview(for: image)
                } else {
                    ContentUnavailableView(
                        "No Image Selected",
                        systemImage: "photo",
                        description: Text("Select an image from the list.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var previewHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedImage?.displayName ?? "Preview")
                    .font(.headline)
                    .lineLimit(1)

                if let selectedImage = model.selectedImage {
                    Text(selectedImage.sourcePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func selectedImagePreview(for image: ImageEntry) -> some View {
        switch model.imageStatus(for: image) {
        case .readable:
            if let nsImage = NSImage(contentsOfFile: image.sourcePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Preview Unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("The file is readable, but macOS could not render it as an image.")
                )
            }
        case .missing:
            ContentUnavailableView(
                "File Missing",
                systemImage: "exclamationmark.triangle",
                description: Text("The source image path no longer exists.")
            )
        case .unreadable:
            ContentUnavailableView(
                "File Unreadable",
                systemImage: "lock",
                description: Text("The source image cannot be opened.")
            )
        }
    }

    private var taggingPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                Text("Tagging")
                    .font(.headline)
                Spacer()
            }

            if let image = model.selectedImage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("File")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(image.displayName ?? URL(fileURLWithPath: image.sourcePath).lastPathComponent)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sentence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Sentence-style classification", text: $userSentence, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveUserSentence)
                    Button {
                        saveUserSentence()
                    } label: {
                        Label("Save Sentence", systemImage: "text.quote")
                    }
                    .disabled(model.selectedImageID == nil)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("tag, comma separated, list", text: $userTags, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveUserTags)
                    Button {
                        saveUserTags()
                    } label: {
                        Label("Save Tags", systemImage: "tag")
                    }
                    .disabled(model.selectedImageID == nil)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Workspace notes", text: $imageNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveImageNotes)
                    Button {
                        saveImageNotes()
                    } label: {
                        Label("Save Notes", systemImage: "note.text")
                    }
                    .disabled(model.selectedImageID == nil)
                }

                Spacer()
            } else {
                ContentUnavailableView(
                    "No Image Selected",
                    systemImage: "tag",
                    description: Text("Select an image to edit tagging fields.")
                )
                Spacer()
            }
        }
        .padding()
    }

    private var imageStatusSummary: some View {
        let summary = model.imageStatusSummary

        return HStack(spacing: 10) {
            Label("\(summary.readable)", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
            Label("\(summary.missing)", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Label("\(summary.unreadable)", systemImage: "lock")
                .foregroundStyle(.red)
            Spacer()
        }
        .font(.caption)
    }

    private var imageList: some View {
        List(selection: $model.selectedImageID) {
            ForEach(model.workspace.images) { image in
                imageListRow(image)
                    .tag(image.id)
            }
        }
    }

    private func imageListRow(_ image: ImageEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: imageStatusSystemImage(for: model.imageStatus(for: image)))
                .foregroundStyle(imageStatusColor(for: model.imageStatus(for: image)))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(locationPath(for: image))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(image.displayName ?? URL(fileURLWithPath: image.sourcePath).lastPathComponent)
                    .font(.body)
                    .lineLimit(1)

                Text(metadataSummary(for: image))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
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
            try model.addImages(paths: panel.urls.map(\.path))
            syncTaggingFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func removeSelectedImage() {
        _ = model.removeSelectedImage()
        syncTaggingFields()
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
            syncWorkspaceFields()
            syncTaggingFields()
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

    private func saveWorkspaceName() {
        model.updateWorkspaceName(workspaceNameInput)
        syncWorkspaceFields()
    }

    private func syncWorkspaceFields() {
        workspaceNameInput = model.workspace.workspace.name
    }

    private func saveUserSentence() {
        do {
            try model.updateSelectedUserSentence(userSentence)
            syncTaggingFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func saveUserTags() {
        do {
            try model.updateSelectedUserTags(userTags)
            syncTaggingFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func saveImageNotes() {
        do {
            try model.updateSelectedImageNotes(imageNotes)
            syncTaggingFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func syncTaggingFields() {
        imageNotes = model.selectedImage?.notes ?? ""
        userSentence = model.selectedImage?.classification.user.sentence ?? ""
        userTags = model.selectedImage?.classification.user.tags.joined(separator: ", ") ?? ""
    }

    private func locationPath(for image: ImageEntry) -> String {
        URL(fileURLWithPath: image.sourcePath).deletingLastPathComponent().path
    }

    private func metadataSummary(for image: ImageEntry) -> String {
        guard let metadata = model.imageMetadata(for: image) else {
            return "Unavailable"
        }

        let modified = metadata.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date"
        let size = metadata.fileSizeBytes.map(formatByteCount) ?? "Unknown size"
        return "\(modified) / \(size)"
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func imageStatusSystemImage(for status: ImageFileStatus) -> String {
        switch status {
        case .readable:
            "checkmark.circle"
        case .missing:
            "exclamationmark.triangle"
        case .unreadable:
            "lock"
        }
    }

    private func imageStatusColor(for status: ImageFileStatus) -> Color {
        switch status {
        case .readable:
            .green
        case .missing:
            .orange
        case .unreadable:
            .red
        }
    }
}
