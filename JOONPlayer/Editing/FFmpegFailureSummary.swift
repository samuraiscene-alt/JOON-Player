import Foundation

struct FFmpegFailureSummary: Equatable {
    enum Category: String {
        case mp4Metadata
        case containerStructure
        case codecInformation
        case damagedStream
        case outputContainer
        case storage
        case permission
        case missingFile
        case unknown
    }

    let category: Category
    let title: String
    let message: String
    let suggestion: String
    let technicalDetails: String

    var canTryReencodeRepair: Bool {
        switch category {
        case .storage, .permission, .missingFile, .mp4Metadata:
            return false
        case .containerStructure,
             .codecInformation,
             .damagedStream,
             .outputContainer,
             .unknown:
            return true
        }
    }

    static func analyze(_ rawLog: String?) -> FFmpegFailureSummary {
        let raw = rawLog?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""

        let log = raw.lowercased()

        if containsAny(
            log,
            [
                "no space left on device",
                "disk full",
                "not enough space"
            ]
        ) {
            return make(
                category: .storage,
                title: "저장 공간이 부족한 것으로 보입니다",
                message: "새 복구 파일을 만들 공간이 부족해서 작업이 중단된 가능성이 큽니다.",
                suggestion: "iPhone/iPad의 여유 저장 공간을 확보한 뒤 다시 시도해 주세요. 재인코딩 복구는 추가 임시 공간이 더 필요할 수 있습니다.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "permission denied",
                "operation not permitted",
                "read-only file system",
                "access denied"
            ]
        ) {
            return make(
                category: .permission,
                title: "파일 접근 권한 문제가 감지됐습니다",
                message: "JOON Player가 원본을 읽거나 새 파일을 쓰는 과정에서 iOS 파일 권한에 막힌 것으로 보입니다.",
                suggestion: "원본을 ‘내 iPhone’의 일반 폴더로 복사한 뒤 다시 열어 복구를 시도해 보세요. 권한 문제가 해결되기 전에는 2차 재인코딩도 같은 이유로 실패합니다.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "no such file or directory",
                "error opening input",
                "failed to open input",
                "could not open input"
            ]
        ) {
            return make(
                category: .missingFile,
                title: "원본 파일을 다시 읽지 못했습니다",
                message: "복구를 시작하는 시점에 원본 파일 경로나 파일 제공자 연결을 사용할 수 없었던 것으로 보입니다.",
                suggestion: "파일 앱에서 원본이 실제로 내려받아져 있는지 확인한 뒤 JOON Player에서 파일을 다시 선택해 주세요.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "moov atom not found",
                "moov atom",
                "truncated moov"
            ]
        ) {
            return make(
                category: .mp4Metadata,
                title: "MP4 핵심 메타데이터 손상 가능성",
                message: "MP4 재생에 필요한 moov 메타데이터를 찾지 못한 흔적이 있습니다. 녹화나 복사가 끝나기 전에 파일이 끊긴 경우에도 발생할 수 있습니다.",
                suggestion: "moov 정보가 완전히 사라졌다면 FFmpeg가 스트림 위치 자체를 파악하지 못해 2차 재인코딩도 어려울 수 있습니다. 원본은 그대로 보관해 주세요.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "ebml header parsing failed",
                "error reading header",
                "invalid data found when processing input",
                "end of file",
                "invalid atom",
                "invalid chunk"
            ]
        ) {
            return make(
                category: .containerStructure,
                title: "영상 파일 구조 손상 가능성",
                message: "컨테이너의 헤더·인덱스·구조 정보를 정상적으로 읽지 못한 것으로 보입니다.",
                suggestion: "VLC에서 일부 구간이라도 재생된다면 2차 재인코딩 복구로 읽을 수 있는 프레임을 새 MP4에 다시 담아볼 수 있습니다.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "decoder not found",
                "unknown decoder",
                "unsupported codec",
                "could not find codec parameters",
                "codec parameters"
            ]
        ) {
            return make(
                category: .codecInformation,
                title: "코덱 또는 스트림 정보 문제",
                message: "영상/오디오 코덱 정보를 충분히 읽지 못했거나 현재 FFmpeg 빌드에서 해당 형식을 처리하지 못한 가능성이 있습니다.",
                suggestion: "2차 재인코딩은 더 길게 스트림을 분석한 뒤 다시 디코딩을 시도합니다. 그래도 디코더 자체가 없는 경우에는 FFmpegKitNext 빌드 옵션 점검이 필요합니다.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "invalid nal unit",
                "non-existing pps",
                "pps id out of range",
                "sps unavailable",
                "error while decoding",
                "corrupt",
                "damaged",
                "missing picture in access unit",
                "packet corrupt"
            ]
        ) {
            return make(
                category: .damagedStream,
                title: "영상 스트림 일부가 손상된 것으로 보입니다",
                message: "프레임이나 패킷 자체의 손상을 나타내는 로그가 발견됐습니다.",
                suggestion: "2차 재인코딩 복구는 손상 패킷을 건너뛰고 읽을 수 있는 프레임만 새 MP4로 다시 만들 수 있습니다. 유실된 프레임 자체를 복원하지는 못합니다.",
                rawLog: raw
            )
        }

        if containsAny(
            log,
            [
                "could not write header",
                "muxer does not support",
                "could not find tag for codec",
                "incorrect codec parameters",
                "error initializing output stream"
            ]
        ) {
            return make(
                category: .outputContainer,
                title: "새 복구 파일을 만드는 과정에서 문제가 생겼습니다",
                message: "원본을 읽는 단계보다 새 MKV 컨테이너에 스트림을 그대로 기록하는 단계에서 호환 문제가 발생한 것으로 보입니다.",
                suggestion: "2차 재인코딩 복구는 영상과 오디오를 표준 MP4용 코덱으로 변환해 다시 저장하므로 이 경우 대안이 될 수 있습니다.",
                rawLog: raw
            )
        }

        return make(
            category: .unknown,
            title: "복구 원인을 자동 분류하지 못했습니다",
            message: "FFmpeg가 복구를 완료하지 못했지만 알려진 대표 오류 패턴과 정확히 일치하지 않았습니다.",
            suggestion: "원본은 보관한 채 2차 재인코딩 복구를 시도해 볼 수 있습니다. 다시 실패하면 아래 기술 로그를 복사해 실기기 점검에 사용해 주세요.",
            rawLog: raw
        )
    }

    private static func containsAny(
        _ source: String,
        _ patterns: [String]
    ) -> Bool {
        patterns.contains { source.contains($0) }
    }

    private static func make(
        category: Category,
        title: String,
        message: String,
        suggestion: String,
        rawLog: String
    ) -> FFmpegFailureSummary {
        FFmpegFailureSummary(
            category: category,
            title: title,
            message: message,
            suggestion: suggestion,
            technicalDetails: compactTechnicalDetails(rawLog)
        )
    }

    private static func compactTechnicalDetails(
        _ rawLog: String
    ) -> String {
        guard !rawLog.isEmpty else {
            return "FFmpeg에서 상세 로그를 반환하지 않았습니다."
        }

        let lines = rawLog
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let selected = Array(lines.suffix(40))
        var text = selected.joined(separator: "\n")

        let maximumLength = 5_000

        if text.count > maximumLength {
            let start = text.index(
                text.endIndex,
                offsetBy: -maximumLength
            )
            text = "…\n" + String(text[start...])
        }

        return text
    }
}
