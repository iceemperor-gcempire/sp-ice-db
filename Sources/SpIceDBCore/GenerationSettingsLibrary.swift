import Foundation

public enum GenerationSettingsLibraryError: Error, Equatable {
    case emptyName
    case settingsNotFound
}

public struct GenerationSettingsLibrary {
    private let idGenerator: () -> UUID

    public init(idGenerator: @escaping () -> UUID = UUID.init) {
        self.idGenerator = idGenerator
    }

    @discardableResult
    public func addSettings(
        name: String,
        providerId: UUID?,
        parameters: [String: JSONValue],
        to document: inout WorkspaceDocument
    ) throws -> GenerationSettings {
        let settings = try makeSettings(
            id: idGenerator(),
            name: name,
            providerId: providerId,
            parameters: parameters
        )

        document.generationSettings.append(settings)
        return settings
    }

    @discardableResult
    public func updateSettings(
        id: UUID,
        name: String,
        providerId: UUID?,
        parameters: [String: JSONValue],
        in document: inout WorkspaceDocument
    ) throws -> GenerationSettings {
        guard let index = document.generationSettings.firstIndex(where: { $0.id == id }) else {
            throw GenerationSettingsLibraryError.settingsNotFound
        }

        let settings = try makeSettings(
            id: id,
            name: name,
            providerId: providerId,
            parameters: parameters
        )
        document.generationSettings[index] = settings
        return settings
    }

    @discardableResult
    public func removeSettings(id: UUID, from document: inout WorkspaceDocument) -> GenerationSettings? {
        guard let index = document.generationSettings.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let removed = document.generationSettings.remove(at: index)
        for imageIndex in document.images.indices {
            for outputIndex in document.images[imageIndex].generatedOutputs.indices
            where document.images[imageIndex].generatedOutputs[outputIndex].settingsId == id {
                document.images[imageIndex].generatedOutputs[outputIndex].settingsId = nil
            }
        }
        return removed
    }

    private func makeSettings(
        id: UUID,
        name: String,
        providerId: UUID?,
        parameters: [String: JSONValue]
    ) throws -> GenerationSettings {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw GenerationSettingsLibraryError.emptyName
        }

        return GenerationSettings(
            id: id,
            name: trimmedName,
            providerId: providerId,
            parameters: normalizedParameters(parameters)
        )
    }

    private func normalizedParameters(_ parameters: [String: JSONValue]) -> [String: JSONValue] {
        parameters.reduce(into: [:]) { result, item in
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return
            }

            result[key] = normalizedValue(item.value)
        }
    }

    private func normalizedValue(_ value: JSONValue) -> JSONValue {
        switch value {
        case .string(let string):
            return .string(string.trimmingCharacters(in: .whitespacesAndNewlines))
        case .object(let object):
            return .object(normalizedParameters(object))
        case .array(let values):
            return .array(values.map(normalizedValue))
        case .number, .bool, .null:
            return value
        }
    }
}
