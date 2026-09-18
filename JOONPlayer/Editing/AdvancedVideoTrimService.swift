import Foundation

enum TrimExportMode: String, CaseIterable, Identifiable {
    case fast
    case precise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            return "빠른 자르기"
        case .precise:
            return "정확 자르기"
        }
    }

    var explanation: String {
        switch self {
        case .fast:
            return "재인코딩을 피해서 빠르고 화질 손실이 없도록 자릅니다."
        case .precise:
            return "선택 지점까지 디코딩한 뒤 다시 인코딩해 키프레임 제약을 없앱니다."
        }
    }
}

enum VideoTrimCoordinator {
    static func export(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double,
        mode: TrimExportMode,
        quality: PreciseTrimQuality = .balanced
    ) async throws -> URL {
        switch mode {
        case .fast:
            return try await exportFast(
                sourceURL: sourceURL,
                startSeconds: startSeconds,
                endSeconds: endSeconds
            )

        case .precise:
            return try await PreciseVideoTrimService.export(
                sourceURL: sourceURL,
                startSeconds: startSeconds,
                endSeconds: endSeconds,
                quality: quality
            )
        }
    }

    private static func exportFast(
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
        FFmpegKitNextRuntime.isAvailable
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
        let duration = endSeconds - startSeconds

        guard startSeconds >= 0, duration >= 0.5 else {
            throw AdvancedTrimError.invalidRange
        }

        guard FFmpegKitNextRuntime.isAvailable else {
            throw AdvancedTrimError.engineNotLinked
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

        do {
            try await FFmpegKitNextRuntime.execute(arguments: arguments)
            return outputURL
        } catch let error as FFmpegKitNextRuntime.ExecutionError {
            try? FileManager.default.removeItem(at: outputURL)

            switch error {
            case .engineNotLinked:
                throw AdvancedTrimError.engineNotLinked
            case .cancelled:
                throw AdvancedTrimError.cancelled
            case .failed(let message):
                throw AdvancedTrimError.failed(message)
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw AdvancedTrimError.failed(error.localizedDescription)
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
