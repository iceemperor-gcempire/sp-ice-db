import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpIceDBAppModel
import SpIceDBCore

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var workspaceNameInput = ""
    @State private var errorMessage: String?

    private let workspaceContentType = UTType(filenameExtension: "spicedb") ?? .json
    private let imageContentTypes: [UTType] = [.image]

    var body: some View {
        imageListView
            .frame(minWidth: 720, minHeight: 520)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        model.newWorkspace()
                        syncWorkspaceFields()
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
            .onAppear {
                syncWorkspaceFields()
            }
            .alert("sp-ice-db", isPresented: errorPresented) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private var imageListView: some View {
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
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func removeSelectedImage() {
        _ = model.removeSelectedImage()
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
