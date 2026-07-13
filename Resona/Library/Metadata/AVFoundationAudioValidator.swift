import AVFoundation
import AudioToolbox
import CoreMedia
import Foundation

actor AVFoundationAudioValidator: AudioValidating {
    func validateAudio(at url: URL) async throws -> ValidatedAudio {
        let container = try identifyContainer(at: url)
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetOverrideMIMETypeKey: container.mimeType]
        )

        do {
            if try await asset.load(.hasProtectedContent) {
                throw AudioValidationError.protectedMedia
            }
            guard try await asset.load(.isPlayable) else {
                throw AudioValidationError.corruptAudio
            }

            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard !audioTracks.isEmpty else {
                throw AudioValidationError.videoOnly
            }
            guard try await containsSupportedCodec(
                in: audioTracks,
                container: container
            ) else {
                throw AudioValidationError.unsupportedCodec
            }

            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            return ValidatedAudio(
                canonicalFileExtension: container.canonicalFileExtension,
                mimeType: container.mimeType,
                durationSeconds: seconds.isFinite && seconds >= 0 ? seconds : nil
            )
        } catch let error as AudioValidationError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AudioValidationError.corruptAudio
        }
    }

    private func identifyContainer(at url: URL) throws -> AudioContainer {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw AudioValidationError.corruptAudio
        }
        defer { try? handle.close() }

        guard let header = try? handle.read(upToCount: 12),
              header.count >= 4 else {
            throw AudioValidationError.corruptAudio
        }
        let bytes = [UInt8](header)

        if header.count >= 12,
           ascii(bytes[0 ..< 4]) == "RIFF",
           ascii(bytes[8 ..< 12]) == "WAVE" {
            return .wave
        }
        if header.count >= 12,
           ascii(bytes[0 ..< 4]) == "FORM",
           ["AIFF", "AIFC"].contains(ascii(bytes[8 ..< 12])) {
            return .aiff
        }
        if header.count >= 8, ascii(bytes[4 ..< 8]) == "ftyp" {
            return .mpeg4Audio
        }
        if ascii(bytes[0 ..< min(3, bytes.count)]) == "ID3"
            || (bytes.count >= 2
                && bytes[0] == 0xFF
                && bytes[1] & 0xE0 == 0xE0) {
            return .mp3
        }
        throw AudioValidationError.unsupportedContainer
    }

    private func containsSupportedCodec(
        in tracks: [AVAssetTrack],
        container: AudioContainer
    ) async throws -> Bool {
        for track in tracks {
            let descriptions = try await track.load(.formatDescriptions)
            for description in descriptions {
                let subtype = CMFormatDescriptionGetMediaSubType(description)
                if container.supportedFormatIDs.contains(subtype) {
                    return true
                }
            }
        }
        return false
    }

    private func ascii(_ bytes: ArraySlice<UInt8>) -> String {
        String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

nonisolated private enum AudioContainer {
    case mp3
    case mpeg4Audio
    case wave
    case aiff

    var canonicalFileExtension: String {
        switch self {
        case .mp3: "mp3"
        case .mpeg4Audio: "m4a"
        case .wave: "wav"
        case .aiff: "aiff"
        }
    }

    var supportedFormatIDs: Set<AudioFormatID> {
        switch self {
        case .mp3:
            [kAudioFormatMPEGLayer3]
        case .mpeg4Audio:
            [kAudioFormatMPEG4AAC, kAudioFormatAppleLossless]
        case .wave, .aiff:
            [kAudioFormatLinearPCM]
        }
    }

    var mimeType: String {
        switch self {
        case .mp3: "audio/mpeg"
        case .mpeg4Audio: "audio/mp4"
        case .wave: "audio/wav"
        case .aiff: "audio/aiff"
        }
    }
}
