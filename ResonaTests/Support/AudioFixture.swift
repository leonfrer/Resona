import Foundation

nonisolated enum AudioFixture {
    static func url(_ name: String, extension fileExtension: String) throws -> URL {
        let bundle = Bundle(for: AudioFixtureBundleToken.self)
        if let url = bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Fixtures"
        ) ?? bundle.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        throw CocoaError(.fileNoSuchFile)
    }
}

private final class AudioFixtureBundleToken {}
