import AVFoundation
import Foundation

enum PreciseVideoTrimService {
    enum PreciseTrimError: LocalizedError {
        case engineNotLinked
        case invalidRange
        case unsupportedSource
        case cannotCreateExporter
        case unsupportedOutput
        case cancelled
        case failed(String?)

        var errorDescription: String? {
            switch self {
            case .engineNotLinked:
                return "이 파일의 정확 자르기는 FFmpegKitNext가 필요합니다. Mac/Xcode에서 FFmpegKitNext를 연결하면 활성화됩니다."
            case .invalidRange:
                return "선택한 자르기 구간이 올바르지 않습니다."
            case .unsupportedSource:
                return "이 영상은 현재 정확 자르기 엔진에서 읽을 수 없습니다."
            case .cannotCreateExporter:
                return "이 영상은 현재 AVFoundation 정확 자르기 방식으로 내보낼 수 없습니다."
            case .unsupportedOutput:
                return "정확 자르기 결과를 저장할 출력 형식을 찾지 못했습니다."
            case .cancelled:
                return "정확 자르기가 취소되었습니다."
            case .failed(let message):
                if let message, !message.isEmpty {
                    return "정확 자르기에 실패했습니다.\n\(message)"
                }
                return "정확 자르기에 실패했습니다."
            }
        }
    }

    static func isAvailable(for sourceURL: URL?) -> Bool {
        guard let sourceURL else { return false }

        switch sourceURL.pathExtension.lowercased() {
        case "mp4", "mov", "m4v":
            return true
        default:
            return FFmpegKitNextRuntime.isAvailable
        }
    }

    static func export(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        guard endSeconds - startSeconds >= 0.5 else {
            throw PreciseTrimError.invalidRange
        }

        if prefersAVFoundation(for: sourceURL) {
            do {
                return try await exportWithAVFoundation(
                    sourceURL: sourceURL,
                    startSeconds: startSeconds,
                    endSeconds: endSeconds
                )
            } catch {
                guard FFmpegKitNextRuntime.isAvailable else {
                    throw error
                }
            }
        }

        guard FFmpegKitNextRuntime.isAvailable else {
            throw PreciseTrimError.engineNotLinked
        }

        return try await exportWithFFmpeg(
            sourceURL: sourceURL,
            startSeconds: startSeconds,
            endSeconds: endSeconds
        )
    }

    private static func prefersAVFoundation(for sourceURL: URL) -> Bool {
        switch sourceURL.pathExtension.lowercased() {
        case "mp4", "mov", "m4v":
            return true
        default:
            return false
        }
    }

    private static func exportWithAVFoundation(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            throw PreciseTrimError.unsupportedSource
        }

        let totalSeconds = duration.seconds

        guard totalSeconds.isFinite, totalSeconds > 0 else {
            throw PreciseTrimError.unsupportedSource
        }

        let start = min(max(startSeconds, 0), totalSeconds)
        let end = min(max(endSeconds, 0), totalSeconds)

        guard end - start >= 0.5 else {
            throw PreciseTrimError.invalidRange
        }

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw PreciseTrimError.cannotCreateExporter
        }

        let preferredTypes: [AVFileType]
        if sourceURL.pathExtension.lowercased() == "mov" {
            preferredTypes = [.mov, .mp4]
        } else {
            preferredTypes = [.mp4, .mov]
        }

        guard let outputType = preferredTypes.first(
            where: { exporter.supportedFileTypes.contains($0) }
        ) else {
            throw PreciseTrimError.unsupportedOutput
        }

        let extensionName = outputType == .mov ? "mov" : "mp4"
        let outputURL = makeOutputURL(
            sourceURL: sourceURL,
            suffix: "precise",
            extensionName: extensionName
        )

        try? FileManager.default.removeItem(at: outputURL)

        exporter.outputURL = outputURL
        exporter.outputFileType = outputType
        exporter.shouldOptimizeForNetworkUse = false
        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(
                seconds: end - start,
                preferredTimescale: 600
            )
        )

        nonisolated(unsafe) let localExporter = exporter

        return try await withCheckedThrowingContinuation { continuation in
            localExporter.exportAsynchronously {
                switch localExporter.status {
                case .completed:
                    continuation.resume(returning: outputURL)

                case .cancelled:
                    continuation.resume(
                        throwing: PreciseTrimError.cancelled
                    )

                case .failed:
                    continuation.resume(
                        throwing: PreciseTrimError.failed(
                            localExporter.error?.localizedDescription
                        )
                    )

                default:
                    continuation.resume(
                        throwing: PreciseTrimError.failed(nil)
                    )
                }
            }
        }
    }

    private static func exportWithFFmpeg(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        let duration = endSeconds - startSeconds

        guard startSeconds >= 0, duration >= 0.5 else {
            throw PreciseTrimError.invalidRange
        }

        let outputURL = makeOutputURL(
            sourceURL: sourceURL,
            suffix: "precise",
            extensionName: "mp4"
        )

        try? FileManager.default.removeItem(at: outputURL)

        let arguments = [
            "-y",
            "-fflags", "+discardcorrupt",
            "-err_detect", "ignore_err",
            "-i", sourceURL.path,
            "-ss", timeArgument(startSeconds),
            "-t", timeArgument(duration),
            "-map", "0:v:0?",
            "-map", "0:a:0?",
            "-map_metadata", "0",
            "-c:v", "mpeg4",
            "-q:v", "2",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "-avoid_negative_ts", "make_zero",
            outputURL.path
        ]

        do {
            try await FFmpegKitNextRuntime.execute(arguments: arguments)
            return outputURL
        } catch let error as FFmpegKitNextRuntime.ExecutionError {
            try? FileManager.default.removeItem(at: outputURL)

            switch error {
            case .engineNotLinked:
                throw PreciseTrimError.engineNotLinked
            case .cancelled:
                throw PreciseTrimError.cancelled
            case .failed(let message):
                throw PreciseTrimError.failed(message)
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw PreciseTrimError.failed(error.localizedDescription)
        }
    }

    private static func makeOutputURL(
        sourceURL: URL,
        suffix: String,
        extensionName: String
    ) -> URL {
        let baseName = sourceURL
            .deletingPathExtension()
            .lastPathComponent

        return FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(baseName)_\(suffix)_\(UUID().uuidString)"
            )
            .appendingPathExtension(extensionName)
    }

    private static func timeArgument(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }
}
