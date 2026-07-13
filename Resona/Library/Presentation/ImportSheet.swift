import SwiftUI
import UniformTypeIdentifiers

struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSelectingFiles = false
    @State private var pickerFailure: ImportSheetPickerFailure?

    let session: ImportSessionModel
    let onDismiss: @MainActor (UUID?) -> Void

    init(
        session: ImportSessionModel,
        onDismiss: @escaping @MainActor (UUID?) -> Void = { _ in }
    ) {
        self.session = session
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            List {
                if session.isActive {
                    progressSection
                } else if session.hasSessionError {
                    sessionErrorSection
                } else {
                    summarySection
                    resultsSection
                }
            }
            .navigationTitle("Import Audio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if session.isActive {
                        Button(session.isCancelling ? "Cancelling…" : "Cancel") {
                            Task {
                                await session.cancel()
                            }
                        }
                        .disabled(session.isCancelling)
                        .accessibilityIdentifier("import.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !session.isActive {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibilityIdentifier("import.done")
                    }
                }
            }
        }
        .interactiveDismissDisabled(session.isActive)
        .fileImporter(
            isPresented: $isSelectingFiles,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        } onCancellation: {
            // The existing results remain visible after picker cancellation.
        }
        .alert(item: $pickerFailure) { failure in
            Alert(
                title: Text("Files Couldn’t Be Opened"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            await session.start()
        }
        .onDisappear {
            onDismiss(session.recoverySongID)
        }
    }

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(
                    value: Double(session.progress.completedFileCount),
                    total: Double(max(session.progress.totalFileCount, 1))
                )
                Text(
                    "\(session.progress.completedFileCount) of \(session.progress.totalFileCount) files completed"
                )
                .font(.headline)

                if let currentName = session.progress.currentSourceDisplayName {
                    Text("Importing \(currentName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var sessionErrorSection: some View {
        Section {
            ContentUnavailableView {
                Label("Import Couldn’t Start", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Resona couldn’t start this import. No selected file was changed.")
            } actions: {
                Button("Try Again") {
                    Task {
                        await session.importNewFiles(
                            at: session.entries.map(\.sourceURL)
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            ImportSummaryRow(
                title: "Imported",
                count: session.summary.importedCount,
                systemImage: "checkmark.circle"
            )
            ImportSummaryRow(
                title: "Restored",
                count: session.summary.restoredCount,
                systemImage: "arrow.clockwise.circle"
            )
            ImportSummaryRow(
                title: "Already Imported",
                count: session.summary.alreadyImportedCount,
                systemImage: "info.circle"
            )
            ImportSummaryRow(
                title: "Failed",
                count: session.summary.failedCount,
                systemImage: "xmark.circle"
            )
            ImportSummaryRow(
                title: "Cancelled",
                count: session.summary.cancelledCount,
                systemImage: "minus.circle"
            )
            if session.summary.warningCount > 0 {
                ImportSummaryRow(
                    title: "Warnings",
                    count: session.summary.warningCount,
                    systemImage: "exclamationmark.circle"
                )
            }
        }
    }

    private var resultsSection: some View {
        Section("Files") {
            ForEach(session.entries) { entry in
                if let result = entry.result {
                    ImportResultRow(
                        entry: entry,
                        result: result,
                        retry: {
                            Task {
                                await session.retry(entryID: entry.id)
                            }
                        },
                        chooseFiles: {
                            isSelectingFiles = true
                        }
                    )
                }
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard !urls.isEmpty else {
                return
            }
            Task {
                await session.importNewFiles(at: urls)
            }
        case let .failure(error):
            pickerFailure = ImportSheetPickerFailure(error: error)
        }
    }
}

private struct ImportSummaryRow: View {
    let title: LocalizedStringResource
    let count: Int
    let systemImage: String

    var body: some View {
        LabeledContent {
            Text(count, format: .number)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct ImportResultRow: View {
    let entry: ImportSessionEntry
    let result: ImportFileResult
    let retry: () -> Void
    let chooseFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(result.sourceDisplayName)
                    .font(.headline)
                    .lineLimit(2)
            } icon: {
                Image(systemName: result.outcome.presentation.systemImage)
                    .foregroundStyle(result.outcome.presentation.iconStyle)
            }

            Text(result.outcome.presentation.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if result.outcome.presentation.actions.contains(.retry) {
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("import.retry.\(entry.id)")
            }
            if result.outcome.presentation.actions.contains(.chooseFiles) {
                Button("Choose Files", action: chooseFiles)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("import.chooseFiles.\(entry.id)")
            }
        }
        .padding(.vertical, 4)
    }
}

private enum ImportRecoveryAction: Hashable {
    case retry
    case chooseFiles
}

private struct ImportOutcomePresentation {
    let message: LocalizedStringResource
    let systemImage: String
    let iconStyle: Color
    let actions: Set<ImportRecoveryAction>
}

private extension ImportFileResult.Outcome {
    var presentation: ImportOutcomePresentation {
        switch self {
        case .imported:
            ImportOutcomePresentation(
                message: "Imported into your library.",
                systemImage: "checkmark.circle.fill",
                iconStyle: .green,
                actions: []
            )
        case .restored:
            ImportOutcomePresentation(
                message: "Restored the existing unavailable song.",
                systemImage: "arrow.clockwise.circle.fill",
                iconStyle: .green,
                actions: []
            )
        case .alreadyImported:
            ImportOutcomePresentation(
                message: "This audio is already in your library.",
                systemImage: "info.circle.fill",
                iconStyle: .secondary,
                actions: []
            )
        case let .warning(_, warnings):
            ImportOutcomePresentation(
                message: warningMessage(warnings),
                systemImage: "exclamationmark.circle.fill",
                iconStyle: .secondary,
                actions: []
            )
        case let .failed(reason):
            ImportOutcomePresentation(
                message: reason.message,
                systemImage: "xmark.circle.fill",
                iconStyle: .red,
                actions: reason.recoveryActions
            )
        case .cancelled:
            ImportOutcomePresentation(
                message: "Import was cancelled. No partial song was added.",
                systemImage: "minus.circle.fill",
                iconStyle: .secondary,
                actions: [.chooseFiles]
            )
        }
    }

    private func warningMessage(
        _ warnings: [ImportWarning]
    ) -> LocalizedStringResource {
        if warnings.contains(.metadataUnreadable) {
            return "Audio imported. Some metadata couldn’t be read, so fallbacks are shown."
        }
        if warnings.contains(.artworkUnreadable) {
            return "Audio imported. The artwork couldn’t be read, so a placeholder is shown."
        }
        return "Audio imported. The artwork couldn’t be saved, so a placeholder is shown."
    }
}

private extension ImportFailureReason {
    var message: LocalizedStringResource {
        switch self {
        case .unsupportedContainer, .unsupportedCodec:
            "This file uses an audio format that Resona doesn’t support."
        case .protectedMedia:
            "This protected audio file can’t be imported."
        case .videoOnly:
            "This file doesn’t contain a supported audio track."
        case .corruptAudio:
            "This file couldn’t be read as valid audio."
        case .sourceAccessLost:
            "Access to this file was lost. Try again or choose the file again."
        case .insufficientStorage:
            "There isn’t enough device storage. Free some space, then try again."
        case .persistenceFailed:
            "The song couldn’t be saved to the library. Try again."
        case .managedStorageFailed:
            "The audio couldn’t be copied into Resona. Try again."
        }
    }

    var recoveryActions: Set<ImportRecoveryAction> {
        switch self {
        case .unsupportedContainer,
             .unsupportedCodec,
             .protectedMedia,
             .videoOnly,
             .corruptAudio:
            [.chooseFiles]
        case .sourceAccessLost:
            [.retry, .chooseFiles]
        case .insufficientStorage, .persistenceFailed, .managedStorageFailed:
            [.retry]
        }
    }
}

private struct ImportSheetPickerFailure: Identifiable {
    let id = UUID()
    let message: String

    init(error: any Error) {
        message = String(
            localized: "The selected files could not be accessed. Choose the files again."
        )
    }
}

#Preview("Importing Multiple Files") {
    ImportSheet(session: .previewImporting())
}

#Preview("Mixed Import Results") {
    ImportSheet(session: .previewMixedResults())
}
