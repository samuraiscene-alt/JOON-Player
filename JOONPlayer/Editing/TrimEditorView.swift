import AVFoundation
import SwiftUI
import UIKit

struct TrimEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: PlayerViewModel

    @State private var startSeconds: Double = 0
    @State private var endSeconds: Double = 1
    @State private var didInitializeRange = false
    @State private var isPreviewing = false
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    private let minimumClipLength: Double = 0.5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sourceSection
                    rangeSection
                    previewSection
                    exportSection
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("영상 자르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        stopPreviewIfNeeded()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            initializeRangeIfNeeded()
        }
        .onChange(of: player.durationSeconds) { _, _ in
            initializeRangeIfNeeded()
        }
        .onChange(of: player.currentSeconds) { _, newValue in
            guard isPreviewing, newValue >= endSeconds else { return }

            if player.isPlaying {
                player.togglePlayback()
            }

            player.seek(to: startSeconds)
            isPreviewing = false
        }
        .onDisappear {
            stopPreviewIfNeeded()
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportedURL {
                ActivityShareSheet(items: [exportedURL])
            }
        }
        .alert(
            "영상 자르기",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("원본", systemImage: "film")
                .font(.headline)

            Text(player.fileName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)

            Text("원본 파일은 변경하거나 삭제하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))

            if AdvancedVideoTrimService.prefersFFmpeg(for: player.currentMediaURL) {
                Label(
                    AdvancedVideoTrimService.isAvailable
                    ? "FFmpegKitNext 빠른 자르기 사용 가능"
                    : "MKV 등 고급 자르기는 Mac/Xcode에서 FFmpegKitNext 연결 후 활성화",
                    systemImage: AdvancedVideoTrimService.isAvailable
                    ? "checkmark.circle"
                    : "hammer"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("자를 구간", systemImage: "scissors")
                .font(.headline)

            trimSlider(
                title: "시작",
                value: $startSeconds,
                range: 0...startSliderUpperBound
            )

            HStack {
                Text(timeText(startSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()

                Button("현재 위치를 시작점") {
                    setStartToCurrentPosition()
                }
                .buttonStyle(.bordered)
            }

            trimSlider(
                title: "끝",
                value: $endSeconds,
                range: endSliderLowerBound...max(player.durationSeconds, 1)
            )

            HStack {
                Text(timeText(endSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()

                Button("현재 위치를 끝점") {
                    setEndToCurrentPosition()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Text("선택 구간")
                    .foregroundStyle(.white.opacity(0.62))

                Spacer()

                Text(timeText(selectedDuration))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var previewSection: some View {
        HStack(spacing: 12) {
            Button {
                player.seek(to: startSeconds)
            } label: {
                Label("시작점 이동", systemImage: "backward.end")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                togglePreview()
            } label: {
                Label(
                    isPreviewing ? "미리보기 중지" : "구간 미리보기",
                    systemImage: isPreviewing ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var exportSection: some View {
        VStack(spacing: 12) {
            Button {
                exportTrimmedVideo()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Text(isExporting ? "새 파일 만드는 중…" : "새 파일로 저장")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || selectedDuration < minimumClipLength)

            Text("완료되면 iOS 공유 화면에서 ‘파일에 저장’을 선택하면 됩니다. MP4/MOV 계열은 AVFoundation을 우선 사용하고, FFmpegKitNext가 연결된 빌드에서는 MKV/AVI/TS/WebM/FLV 등도 스트림 복사 방식의 빠른 자르기를 사용합니다. 외부 SRT 자막은 새 영상에 포함하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.46))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func trimSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            Slider(value: value, in: range)
                .tint(.white)
        }
    }

    private var selectedDuration: Double {
        max(endSeconds - startSeconds, 0)
    }

    private var startSliderUpperBound: Double {
        max(min(endSeconds - minimumClipLength, player.durationSeconds), 0)
    }

    private var endSliderLowerBound: Double {
        min(
            max(startSeconds + minimumClipLength, minimumClipLength),
            max(player.durationSeconds, minimumClipLength)
        )
    }

    private func initializeRangeIfNeeded() {
        guard !didInitializeRange, player.durationSeconds > 0 else { return }

        startSeconds = 0
        endSeconds = player.durationSeconds
        didInitializeRange = true
    }

    private func setStartToCurrentPosition() {
        let maximum = max(endSeconds - minimumClipLength, 0)
        startSeconds = min(max(player.currentSeconds, 0), maximum)
    }

    private func setEndToCurrentPosition() {
        let minimum = startSeconds + minimumClipLength
        endSeconds = min(
            max(player.currentSeconds, minimum),
            max(player.durationSeconds, minimum)
        )
    }

    private func togglePreview() {
        if isPreviewing {
            stopPreviewIfNeeded()
            return
        }

        if player.isPlaying {
            player.togglePlayback()
        }

        player.seek(to: startSeconds)
        player.togglePlayback()
        isPreviewing = true
    }

    private func stopPreviewIfNeeded() {
        guard isPreviewing else { return }

        if player.isPlaying {
            player.togglePlayback()
        }

        isPreviewing = false
    }

    private func exportTrimmedVideo() {
        guard let sourceURL = player.currentMediaURL else {
            errorMessage = "현재 영상 파일 위치를 확인할 수 없습니다."
            return
        }

        guard selectedDuration >= minimumClipLength else {
            errorMessage = "최소 0.5초 이상의 구간을 선택해 주세요."
            return
        }

        stopPreviewIfNeeded()

        if player.isPlaying {
            player.togglePlayback()
        }

        isExporting = true

        Task {
            do {
                let url = try await VideoTrimCoordinator.export(
                    sourceURL: sourceURL,
                    startSeconds: startSeconds,
                    endSeconds: endSeconds
                )

                await MainActor.run {
                    exportedURL = url
                    isExporting = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }

        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%02d:%02d", minutes, secs)
    }
}

enum VideoTrimService {
    enum TrimError: LocalizedError {
        case invalidRange
        case unsupportedSource
        case cannotCreateExporter
        case unsupportedOutput
        case cancelled
        case failed(Error?)
        case unknown

        var errorDescription: String? {
            switch self {
            case .invalidRange:
                return "선택한 자르기 구간이 올바르지 않습니다."
            case .unsupportedSource:
                return "이 파일은 현재 빠른 자르기 엔진에서 읽을 수 없습니다. MKV 등 일부 형식은 이후 FFmpeg 계열 편집 엔진에서 지원할 예정입니다."
            case .cannotCreateExporter:
                return "이 영상의 코덱 또는 컨테이너는 현재 빠른 자르기를 지원하지 않습니다."
            case .unsupportedOutput:
                return "이 영상에서 새 파일을 만들 수 있는 출력 형식을 찾지 못했습니다."
            case .cancelled:
                return "영상 자르기가 취소되었습니다."
            case .failed(let error):
                return error?.localizedDescription ?? "영상 자르기에 실패했습니다."
            case .unknown:
                return "영상 자르기 중 알 수 없는 오류가 발생했습니다."
            }
        }
    }

    static func export(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            throw TrimError.unsupportedSource
        }

        let totalSeconds = duration.seconds

        guard totalSeconds.isFinite, totalSeconds > 0 else {
            throw TrimError.unsupportedSource
        }

        let start = min(max(startSeconds, 0), totalSeconds)
        let end = min(max(endSeconds, 0), totalSeconds)

        guard end - start >= 0.5 else {
            throw TrimError.invalidRange
        }

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw TrimError.cannotCreateExporter
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
            throw TrimError.unsupportedOutput
        }

        let outputExtension = outputType == .mov ? "mov" : "mp4"
        let baseName = sourceURL
            .deletingPathExtension()
            .lastPathComponent

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_trim_\(UUID().uuidString)")
            .appendingPathExtension(outputExtension)

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
                    continuation.resume(throwing: TrimError.cancelled)

                case .failed:
                    continuation.resume(
                        throwing: TrimError.failed(localExporter.error)
                    )

                default:
                    continuation.resume(throwing: TrimError.unknown)
                }
            }
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
