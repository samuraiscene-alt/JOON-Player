import Foundation

enum VideoRepairMode: String, CaseIterable, Identifiable {
    case quickRemux
    case reencode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickRemux:
            return "빠른 복구"
        case .reencode:
            return "2차 재인코딩"
        }
    }

    var explanation: String {
        switch self {
        case .quickRemux:
            return "재인코딩 없이 읽을 수 있는 스트림을 새 MKV에 다시 담아 빠르게 복구를 시도합니다."
        case .reencode:
            return "읽을 수 있는 프레임을 다시 디코딩·인코딩해 새 MP4로 만듭니다. 더 오래 걸리지만 스트림 복사로 실패한 파일을 일부 건질 수 있습니다."
        }
    }
}

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
                return "영상 복구 기능은 FFmpegKitNext가 필요합니다. Mac/Xcode 빌드 단계에서 FFmpegKitNext를 연결하면 활성화됩니다."
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

    static func repair(
        sourceURL: URL,
        mode: VideoRepairMode
    ) async throws -> URL {
        guard isAvailable else {
            throw RepairError.engineNotLinked
        }

        switch mode {
        case .quickRemux:
            return try await quickRemux(sourceURL: sourceURL)

        case .reencode:
            return try await reencodeRecovery(sourceURL: sourceURL)
        }
    }

    private static func quickRemux(
        sourceURL: URL
    ) async throws -> URL {
        let outputURL = repairedOutputURL(
            for: sourceURL,
            suffix: "repaired",
            extensionName: "mkv"
        )

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

        return try await runRepair(
            arguments: arguments,
            outputURL: outputURL
        )
    }

    private static func reencodeRecovery(
        sourceURL: URL
    ) async throws -> URL {
        let outputURL = repairedOutputURL(
            for: sourceURL,
            suffix: "recovered",
            extensionName: "mp4"
        )

        let arguments = [
            "-y",
            "-fflags", "+genpts+discardcorrupt",
            "-err_detect", "ignore_err",
            "-analyzeduration", "100M",
            "-probesize", "100M",
            "-i", sourceURL.path,
            "-map", "0:v:0?",
            "-map", "0:a:0?",
            "-map_metadata", "0",
            "-c:v", "mpeg4",
            "-q:v", "4",
            "-c:a", "aac",
            "-b:a", "160k",
            "-max_muxing_queue_size", "4096",
            "-movflags", "+faststart",
            "-avoid_negative_ts", "make_zero",
            outputURL.path
        ]

        return try await runRepair(
            arguments: arguments,
            outputURL: outputURL
        )
    }

    private static func runRepair(
        arguments: [String],
        outputURL: URL
    ) async throws -> URL {
        try? FileManager.default.removeItem(at: outputURL)

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

    private static func repairedOutputURL(
        for sourceURL: URL,
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
}
