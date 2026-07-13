import SwiftUI
import UniformTypeIdentifiers

private struct AudioImportPresentationModifier: ViewModifier {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.audioImporter) private var audioImporter

    @Binding var isSelectingFiles: Bool
    @State private var importSession: ImportSessionModel?
    @State private var pickerFailure: AudioImportPickerFailure?

    let onSessionDismiss: @MainActor (UUID?) -> Void

    init(
        isSelectingFiles: Binding<Bool>,
        initialSession: ImportSessionModel?,
        onSessionDismiss: @escaping @MainActor (UUID?) -> Void
    ) {
        _isSelectingFiles = isSelectingFiles
        _importSession = State(initialValue: initialSession)
        self.onSessionDismiss = onSessionDismiss
    }

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isSelectingFiles,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            } onCancellation: {
                // Picker cancellation intentionally leaves current state unchanged.
            }
            .sheet(item: $importSession) { session in
                ImportSheet(
                    session: session,
                    onDismiss: onSessionDismiss
                )
            }
            .alert(item: $pickerFailure) { failure in
                Alert(
                    title: Text("Files Couldn’t Be Opened"),
                    message: Text(failure.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    private func handleFileSelection(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard !urls.isEmpty else {
                return
            }
            importSession = ImportSessionModel(
                sourceURLs: urls,
                audioImporter: audioImporter,
                libraryStore: libraryStore
            )
        case let .failure(error):
            pickerFailure = AudioImportPickerFailure(error: error)
        }
    }
}

extension View {
    func audioImportPresentation(
        isSelectingFiles: Binding<Bool>,
        initialSession: ImportSessionModel? = nil,
        onSessionDismiss: @escaping @MainActor (UUID?) -> Void = { _ in }
    ) -> some View {
        modifier(
            AudioImportPresentationModifier(
                isSelectingFiles: isSelectingFiles,
                initialSession: initialSession,
                onSessionDismiss: onSessionDismiss
            )
        )
    }
}

private struct AudioImportPickerFailure: Identifiable {
    let id = UUID()
    let message: String

    init(error: any Error) {
        message = String(
            localized: "The selected files could not be accessed. Choose the files again."
        )
    }
}
