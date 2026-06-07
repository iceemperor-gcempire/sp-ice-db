import Foundation

public enum AIProviderLibraryError: Error, Equatable {
    case emptyName
    case invalidBaseURL
    case emptyModel
    case providerNotFound
}

public struct AIProviderLibrary {
    private let idGenerator: () -> UUID

    public init(idGenerator: @escaping () -> UUID = UUID.init) {
        self.idGenerator = idGenerator
    }

    @discardableResult
    public func addProvider(
        name: String,
        baseURL: String,
        model: String,
        apiKeyRef: String?,
        supportsImageInput: Bool = true,
        timeoutSeconds: TimeInterval = 60,
        customHeaders: [String: String] = [:],
        to document: inout WorkspaceDocument
    ) throws -> AIProviderProfile {
        let profile = try makeProvider(
            id: idGenerator(),
            name: name,
            baseURL: baseURL,
            model: model,
            apiKeyRef: apiKeyRef,
            supportsImageInput: supportsImageInput,
            timeoutSeconds: timeoutSeconds,
            customHeaders: customHeaders
        )

        document.aiProviders.append(profile)
        return profile
    }

    @discardableResult
    public func updateProvider(
        id: UUID,
        name: String,
        baseURL: String,
        model: String,
        apiKeyRef: String?,
        supportsImageInput: Bool = true,
        timeoutSeconds: TimeInterval = 60,
        customHeaders: [String: String] = [:],
        in document: inout WorkspaceDocument
    ) throws -> AIProviderProfile {
        guard let index = document.aiProviders.firstIndex(where: { $0.id == id }) else {
            throw AIProviderLibraryError.providerNotFound
        }

        let profile = try makeProvider(
            id: id,
            name: name,
            baseURL: baseURL,
            model: model,
            apiKeyRef: apiKeyRef,
            supportsImageInput: supportsImageInput,
            timeoutSeconds: timeoutSeconds,
            customHeaders: customHeaders
        )

        document.aiProviders[index] = profile
        return profile
    }

    @discardableResult
    public func removeProvider(id: UUID, from document: inout WorkspaceDocument) -> AIProviderProfile? {
        guard let index = document.aiProviders.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return document.aiProviders.remove(at: index)
    }

    private func makeProvider(
        id: UUID,
        name: String,
        baseURL: String,
        model: String,
        apiKeyRef: String?,
        supportsImageInput: Bool,
        timeoutSeconds: TimeInterval,
        customHeaders: [String: String]
    ) throws -> AIProviderProfile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AIProviderLibraryError.emptyName
        }

        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedBaseURL),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            throw AIProviderLibraryError.invalidBaseURL
        }

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw AIProviderLibraryError.emptyModel
        }

        let trimmedAPIKeyRef = apiKeyRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AIProviderProfile(
            id: id,
            name: trimmedName,
            baseURL: url,
            model: trimmedModel,
            apiKeyRef: trimmedAPIKeyRef?.isEmpty == true ? nil : trimmedAPIKeyRef,
            supportsImageInput: supportsImageInput,
            timeoutSeconds: timeoutSeconds,
            customHeaders: customHeaders
        )
    }
}

