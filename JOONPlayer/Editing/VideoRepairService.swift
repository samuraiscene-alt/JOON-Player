import Foundation

enum VideoRepairService {
    enum RepairError: LocalizedError {
        case engineNotLinked
        case missingSource
        case cancelled
        case emptyOutput
        case failed(FFmpegFailureSummary)

        var errorDescription: String? {
            switch self {
            case .engineNotLinked:
                return "영상 복구/리먹스 기능은 FFmpegKitNext가 필요합니다. Mac/Xcode 빌드 단계에서 FFmpegKitNext를 연결하면 활성화됩니다."
            case .missingSource:
                return "현재 영상 파일 위치를 확인할 수 없습니다."
            case .cancelled:
                return "영상 복구가 취소되었습니다."
            case .emptyOutput:
                return "복구 작업은 끝났지만 재생 가능한 결과 파일을 만들지 못했습니다."
            case .failed(let report):
                return report.message
            }
        }

        var failureSummary: FFmpegFailureSummary? {
            guard case .failed(let report) = self else {
                return nil
            }
            return report
        }
    }

    static var isAvailable: Bool {
        FFmpegKitNextRuntime.isAvailable
    }

    static func repair(sourceURL: URL) async throws -> URL {
        guard isAvailable else {
            throw RepairError.engineNotLinked
        }

        let outputURL = repairedOutputURL(for: sourceURL)
        try? FileManager.default.removeItem(at: outputURL)

        let arguments = [
            "-y",
            "-fflags", "+genpts+discardcorrupt",
            "-err_detect", "ignore_err",
            "-i", sourceURL.path,
            "-map", "0:v?",
            "-map", "0:a?",
            "-map", "0:s?",
            "-map_metadata", "0",
            "-c", "copy",
            "-avoid_negative_ts", "make_zero",
            outputURL.path
        ]

        do {
            try await FFmpegKitNextRuntime.execute(arguments: arguments)
        } catch let error as FFmpegKitNextRuntime.ExecutionError {
            try? FileManager.default.removeItem(at: outputURL)

            switch error {
            case .engineNotLinked:
                throw RepairError.engineNotLinked
            case .cancelled:
                throw RepairError.cancelled
            case .failed(let message):
                throw RepairError.failed(
                    FFmpegFailureSummary.analyze(message)
                )
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw RepairError.failed(
                FFmpegFailureSummary.analyze(
                    error.localizedDescription
                )
            )
        }

        guard
            FileManager.default.fileExists(atPath: outputURL.path),
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: outputURL.path
            ),
            let size = attributes[.size] as? NSNumber,
            size.int64Value > 0
        else {
            try? FileManager.default.removeItem(at: outputURL)
            throw RepairError.emptyOutput
        }

        return outputURL
    }

    private static func repairedOutputURL(for sourceURL: URL) -> URL {
        let baseName = sourceURL
            .deletingPathExtension()
            .lastPathComponent

        return FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(baseName)_repaired_\(UUID().uuidString)"
            )
            .appendingPathExtension("mkv")
    }
}
