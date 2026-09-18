import Foundation

#if canImport(ffmpegkit)
@preconcurrency import ffmpegkit
#endif

enum FFmpegKitNextRuntime {
    enum ExecutionError: LocalizedError {
        case engineNotLinked
        case cancelled
        case failed(String?)

        var errorDescription: String? {
            switch self {
            case .engineNotLinked:
                return "FFmpegKitNext가 아직 이 빌드에 연결되지 않았습니다."
            case .cancelled:
                return "FFmpeg 작업이 취소되었습니다."
            case .failed(let message):
                if let message, !message.isEmpty {
                    return message
                }
                return "FFmpeg 작업에 실패했습니다."
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

    #if canImport(ffmpegkit)
    private static let executionQueue = DispatchQueue(
        label: "com.joonplayer.ffmpeg.serial",
        qos: .utility
    )
    #endif

    static func execute(arguments: [String]) async throws {
        #if canImport(ffmpegkit)
        try await withCheckedThrowingContinuation { continuation in
            FFmpegKit.execute(
                withArgumentsAsync: arguments,
                withCompleteCallback: { session in
                    let returnCode = session?.getReturnCode()

                    if ReturnCode.isSuccess(returnCode) {
                        continuation.resume()
                        return
                    }

                    if ReturnCode.isCancel(returnCode) {
                        continuation.resume(
                            throwing: ExecutionError.cancelled
                        )
                        return
                    }

                    let output = session?.getOutput()
                    let failStackTrace = session?.getFailStackTrace()

                    let details = [output, failStackTrace]
                        .compactMap { value -> String? in
                            guard let value, !value.isEmpty else {
                                return nil
                            }
                            return value
                        }
                        .joined(separator: "\n")

                    continuation.resume(
                        throwing: ExecutionError.failed(
                            details.isEmpty ? nil : details
                        )
                    )
                },
                withLogCallback: nil,
                withStatisticsCallback: nil,
                onDispatchQueue: executionQueue
            )
        }
        #else
        throw ExecutionError.engineNotLinked
        #endif
    }
}
