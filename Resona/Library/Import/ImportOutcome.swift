import Foundation

nonisolated struct ImportFileResult: Equatable, Sendable {
    let sourceDisplayName: String
    let outcome: Outcome

    nonisolated enum Outcome: Equatable, Sendable {
        case imported(UUID)
        case restored(UUID)
        case alreadyImported(UUID)
        case warning(UUID, [ImportWarning])
        case failed(ImportFailureReason)
        case cancelled
    }
}

nonisolated enum ImportFailureReason: Equatable, Sendable {
    case unsupportedContainer
    case unsupportedCodec
    case protectedMedia
    case videoOnly
    case corruptAudio
    case sourceAccessLost
    case insufficientStorage
    case persistenceFailed
    case managedStorageFailed
}

nonisolated enum ImportWarning: Equatable, Sendable {
    case metadataUnreadable
    case artworkUnreadable
    case artworkStorageFailed
}

nonisolated struct ImportProgress: Equatable, Sendable {
    let completedFileCount: Int
    let totalFileCount: Int
    let currentSourceDisplayName: String?
}

nonisolated enum ImportEvent: Equatable, Sendable {
    case progress(ImportProgress)
    case result(ImportFileResult)
    case finished
}
