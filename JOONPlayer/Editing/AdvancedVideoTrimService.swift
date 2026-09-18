import Foundation

#if canImport(ffmpegkit)
@preconcurrency import ffmpegkit
#endif

enum VideoTrimCoordinator {
    static func export(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        if AdvancedVideoTrimService.prefersFFmpeg(for: sourceURL) {
            return try await AdvancedVideoTrimService.export(
                sourceURL: sourceURL,
                startSeconds: startSeconds,
                endSeconds: endSeconds
            )
        }

        do {
            return try await VideoTrimService.export(
                sourceURL: sourceURL,
                startSeconds: startSeconds,
                endSeconds: endSeconds
            )
        } catch {
            guard AdvancedVideoTrimService.isAvailable else {
                throw error
            }

            return try await AdvancedVideoTrimService.export(
                sourceURL: sourceURL,
                startSeconds: startSeconds,
                endSeconds: endSeconds
            )
        }
    }
}

enum AdvancedVideoTrimService {
    enum AdvancedTrimError: LocalizedError {
        case engineNotLinked
        case invalidRange
        case cancelled
        case failed(String?)

        var errorDescription: String? {
            switch self {
            case .engineNotLinked:
                return "이 형식의 빠른 자르기는 FFmpegKitNext가 필요합니다. Mac/Xcode 빌드 단계에서 공식 FFmpegKitNext를 연결하면 MKV 등 고급 형식 자르기가 활성화됩니다."
            case .invalidRange:
                return "선택한 자르기 구간이 올바르지 않습니다."
            case .cancelled:
                return "영상 자르기가 취소되었습니다."
            case .failed(let message):
                if let message, !message.isEmpty {
                    return "FFmpeg 자르기에 실패했습니다.\n\(message)"
                }
                return "FFmpeg 자르기에 실패했습니다."
            }
        }
    }

    static var isAvailable: Bool {
        #if canImport(ffmpegkit)
        true
        #else
        false
        #endif
    }

    static func prefersFFmpeg(for sourceURL: URL?) -> Bool {
        guard let sourceURL else { return false }

        switch sourceURL.pathExtension.lowercased() {
        case "mp4", "mov", "m4v":
            return false
        default:
            return true
        }
    }

    static func export(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        guard endSeconds - startSeconds >= 0.5 else {
            throw AdvancedTrimError.invalidRange
        }

        #if canImport(ffmpegkit)
        return try await FFmpegKitNextBridge.export(
            sourceURL: sourceURL,
            startSeconds: startSeconds,
            endSeconds: endSeconds
        )
        #else
        throw AdvancedTrimError.engineNotLinked
        #endif
    }
}

#if canImport(ffmpegkit)
private enum FFmpegKitNextBridge {
    private static let ffmpegQueue = DispatchQueue(
        label: "com.joonplayer.ffmpeg.serial",
        qos: .utility
    )

    static func export(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        let duration = endSeconds - startSeconds

        guard startSeconds >= 0, duration >= 0.5 else {
            throw AdvancedVideoTrimService.AdvancedTrimError.invalidRange
        }

        let outputURL = makeOutputURL(for: sourceURL)

        try? FileManager.default.removeItem(at: outputURL)

        let arguments = [
            "-y",
            "-fflags", "+discardcorrupt",
            "-err_detect", "ignore_err",
            "-ss", timeArgument(startSeconds),
            "-i", sourceURL.path,
            "-t", timeArgument(duration),
            "-map", "0:v:0?",
            "-map", "0:a?",
            "-map_metadata", "0",
            "-c", "copy",
            "-avoid_negative_ts", "make_zero",
            outputURL.path
        ]

        return try await withCheckedThrowingContinuation { continuation in
            FFmpegKit.execute(
                withArgumentsAsync: arguments,
                withCompleteCallback: { session in
                    let returnCode = session?.getReturnCode()

                    if ReturnCode.isSuccess(returnCode) {
                        continuation.resume(returning: outputURL)
                        return
                    }

                    try? FileManager.default.removeItem(at: outputURL)

                    if ReturnCode.isCancel(returnCode) {
                        continuation.resume(
                            throwing: AdvancedVideoTrimService.AdvancedTrimError.cancelled
                        )
                        return
                    }

                    let details =
                        session?.getFailStackTrace()
                        ?? session?.getOutput()

                    continuation.resume(
                        throwing: AdvancedVideoTrimService.AdvancedTrimError.failed(
                            details
                        )
                    )
                },
                withLogCallback: nil,
                withStatisticsCallback: nil,
                onDispatchQueue: ffmpegQueue
            )
        }
    }

    private static func makeOutputURL(for sourceURL: URL) -> URL {
        let sourceExtension = sourceURL.pathExtension.lowercased()

        let outputExtension: String
        switch sourceExtension {
        case "mkv", "avi", "ts", "m2ts", "webm", "flv", "mp4", "mov", "m4v":
            outputExtension = sourceExtension
        default:
            outputExtension = "mkv"
        }

        let baseName = sourceURL
            .deletingPathExtension()
            .lastPathComponent

        return FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(baseName)_trim_\(UUID().uuidString)"
            )
            .appendingPathExtension(outputExtension)
    }

    private static func timeArgument(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }
}
#endif
