import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpIceDBAppModel
import SpIceDBCore

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var imagePathInput = ""
    @State private var workspaceNameInput = ""
    @State private var userSentence = ""
    @State private var userTags = ""
    @State private var imageNotes = ""
    @State private var selectedProviderID: UUID?
    @State private var providerName = ""
    @State private var providerBaseURL = ""
    @State private var providerModel = ""
    @State private var providerAPIKeyRef = ""
    @State private var providerSupportsImageInput = true
    @State private var providerTimeoutSeconds = 60.0
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
                    syncWorkspaceFields()
                    syncEditorFields()
                    selectedProviderID = nil
                    syncProviderFields()
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

                Button {
                    chooseWorkingDirectory()
                } label: {
                    Label("Working Directory", systemImage: "externaldrive")
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
            syncEditorFields()
        }
        .onChange(of: selectedProviderID) {
            syncProviderFields()
        }
        .onAppear {
            syncWorkspaceFields()
            syncEditorFields()
            selectedProviderID = model.workspace.aiProviders.first?.id
            syncProviderFields()
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Working Directory")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(model.workspace.workspace.workingDirectory ?? "Not set")
                        .font(.caption)
                        .foregroundStyle(model.workspace.workspace.workingDirectory == nil ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        chooseWorkingDirectory()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        clearWorkingDirectory()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.workspace.workspace.workingDirectory == nil)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            imageStatusSummary
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(selection: $model.selectedImageID) {
                ForEach(model.workspace.images, id: \.id) { image in
                    HStack(spacing: 8) {
                        Image(systemName: imageStatusSystemImage(for: model.imageStatus(for: image)))
                            .foregroundStyle(imageStatusColor(for: model.imageStatus(for: image)))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(image.displayName ?? image.sourcePath)
                                .lineLimit(1)
                            Text(image.sourcePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(image.id)
                }
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

    private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            imagePathBar
            GroupBox("AI Provider") {
                providerEditor
            }

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

                TextField("Notes", text: $imageNotes, axis: .vertical)
                    .lineLimit(2...5)
                    .onSubmit(saveImageNotes)

                Button("Save Notes") {
                    saveImageNotes()
                }
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

            Section("AI Classification") {
                if let ai = image.classification.ai {
                    LabeledContent("Sentence", value: ai.sentence)
                    LabeledContent("Tags", value: ai.tags.joined(separator: ", "))
                    LabeledContent("Model", value: ai.model ?? "")
                    LabeledContent("Generated", value: ai.generatedAt?.formatted() ?? "")

                    Button {
                        promoteAIClassification()
                    } label: {
                        Label("Use As User Classification", systemImage: "arrow.down.doc")
                    }
                } else {
                    ContentUnavailableView(
                        "No AI Classification",
                        systemImage: "sparkles",
                        description: Text("Run classification with the selected provider.")
                    )
                }

                Button {
                    classifySelectedImage()
                } label: {
                    Label(
                        model.isClassifyingSelectedImage ? "Classifying" : "Classify With AI",
                        systemImage: "sparkles"
                    )
                }
                .disabled(selectedProviderID == nil
                    || model.selectedImageID == nil
                    || model.selectedImageStatus != .readable
                    || model.isClassifyingSelectedImage)
            }

            Section {
                Button(role: .destructive) {
                    removeSelectedImage()
                } label: {
                    Label("Remove From Workspace", systemImage: "minus.circle")
                }
            }
        }
    }

    private var providerEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Provider", selection: providerSelection) {
                Text("New Provider").tag(Optional<UUID>.none)
                ForEach(model.workspace.aiProviders, id: \.id) { provider in
                    Text(provider.name).tag(Optional(provider.id))
                }
            }
            .pickerStyle(.menu)

            TextField("Name", text: $providerName)
                .textFieldStyle(.roundedBorder)

            TextField("Base URL", text: $providerBaseURL)
                .textFieldStyle(.roundedBorder)

            TextField("Model", text: $providerModel)
                .textFieldStyle(.roundedBorder)

            TextField("API key reference", text: $providerAPIKeyRef)
                .textFieldStyle(.roundedBorder)

            Toggle("Supports image input", isOn: $providerSupportsImageInput)

            Stepper(
                value: $providerTimeoutSeconds,
                in: 5...600,
                step: 5
            ) {
                Text("Timeout \(Int(providerTimeoutSeconds))s")
            }

            HStack {
                Button {
                    saveProvider()
                } label: {
                    Label(selectedProviderID == nil ? "Add Provider" : "Update Provider", systemImage: "network")
                }
                .disabled(providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || providerModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    resetProviderDraft()
                } label: {
                    Label("New", systemImage: "plus")
                }

                Button(role: .destructive) {
                    removeProvider()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(selectedProviderID == nil)
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

    private var providerSelection: Binding<UUID?> {
        Binding(
            get: { selectedProviderID },
            set: { selectedProviderID = $0 }
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
            try model.addImages(paths: panel.urls.map(\.path))
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a working directory for generated training images."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        model.setWorkingDirectory(url.path)
    }

    private func clearWorkingDirectory() {
        model.setWorkingDirectory(nil)
    }

    private func removeSelectedImage() {
        _ = model.removeSelectedImage()
        syncEditorFields()
    }

    private func saveProvider() {
        do {
            if let selectedProviderID {
                try model.updateAIProvider(
                    id: selectedProviderID,
                    name: providerName,
                    baseURL: providerBaseURL,
                    model: providerModel,
                    apiKeyRef: providerAPIKeyRef,
                    supportsImageInput: providerSupportsImageInput,
                    timeoutSeconds: providerTimeoutSeconds
                )
            } else {
                let provider = try model.addAIProvider(
                    name: providerName,
                    baseURL: providerBaseURL,
                    model: providerModel,
                    apiKeyRef: providerAPIKeyRef,
                    supportsImageInput: providerSupportsImageInput,
                    timeoutSeconds: providerTimeoutSeconds
                )
                selectedProviderID = provider.id
            }
            syncProviderFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func removeProvider() {
        guard let selectedProviderID else {
            return
        }

        _ = model.removeAIProvider(id: selectedProviderID)
        self.selectedProviderID = model.workspace.aiProviders.first?.id
        syncProviderFields()
    }

    private func resetProviderDraft() {
        selectedProviderID = nil
        syncProviderFields()
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
            syncEditorFields()
            selectedProviderID = model.workspace.aiProviders.first?.id
            syncProviderFields()
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

    private func saveImageNotes() {
        do {
            try model.updateSelectedImageNotes(imageNotes)
            syncEditorFields()
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

    private func classifySelectedImage() {
        guard let selectedProviderID else {
            return
        }

        Task {
            do {
                try await model.classifySelectedImage(providerID: selectedProviderID)
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    private func promoteAIClassification() {
        do {
            try model.promoteSelectedAIClassificationToUser()
            syncEditorFields()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func syncEditorFields() {
        imageNotes = model.selectedImage?.notes ?? ""
        userSentence = model.selectedImage?.classification.user.sentence ?? ""
        userTags = model.selectedImage?.classification.user.tags.joined(separator: ", ") ?? ""
    }

    private func syncWorkspaceFields() {
        workspaceNameInput = model.workspace.workspace.name
    }

    private func syncProviderFields() {
        guard let provider = model.workspace.aiProviders.first(where: { $0.id == selectedProviderID }) else {
            providerName = ""
            providerBaseURL = ""
            providerModel = ""
            providerAPIKeyRef = ""
            providerSupportsImageInput = true
            providerTimeoutSeconds = 60
            return
        }

        providerName = provider.name
        providerBaseURL = provider.baseURL.absoluteString
        providerModel = provider.model
        providerAPIKeyRef = provider.apiKeyRef ?? ""
        providerSupportsImageInput = provider.supportsImageInput
        providerTimeoutSeconds = provider.timeoutSeconds
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
