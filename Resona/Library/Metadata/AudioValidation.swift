import Foundation

nonisolated protocol AudioValidating: Sendable {
    func validateAudio(at url: URL) async throws -> ValidatedAudio
}

nonisolated struct ValidatedAudio: Equatable, Sendable {
    let canonicalFileExtension: String
    let mimeType: String
    let durationSeconds: Double?
}

nonisolated enum AudioValidationError: Error, Equatable, Sendable {
    case unsupportedContainer
    case unsupportedCodec
    case protectedMedia
    case videoOnly
    case corruptAudio
}
