import SwiftUI
import UIKit

struct VideoRepairView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: PlayerViewModel

    @State private var repairMode: VideoRepairMode = .quickRemux
    @State private var isRepairing = false
    @State private var repairTask: Task<Void, Never>?
    @State private var repairedURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var failureSummary: FFmpegFailureSummary?
    @State private var showTechnicalDetails = false
    @State private var didCopyTechnicalLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceSection
                    engineSection
                    repairModeSection
                    explanationSection

                    if let failureSummary {
                        failureSection(failureSummary)
                    }

                    repairButton
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("영상 복구")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .disabled(isRepairing)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isRepairing)
        .onChange(of: repairMode) { _, _ in
            failureSummary = nil
            showTechnicalDetails = false
            didCopyTechnicalLog = false
        }
        .onDisappear {
            repairTask?.cancel()
            repairTask = nil

            if !showShareSheet {
                cleanupRepairedOutput()
            }
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: cleanupRepairedOutput
        ) {
            if let repairedURL {
                RepairShareSheet(items: [repairedURL])
            }
        }
        .alert(
            "영상 복구",
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

            Text("원본 파일은 수정하거나 덮어쓰지 않습니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))
        }
    }

    private var engineSection: some View {
        HStack(spacing: 10) {
            Image(
                systemName: VideoRepairService.isAvailable
                ? "checkmark.circle"
                : "hammer"
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    VideoRepairService.isAvailable
                    ? "FFmpegKitNext 복구 엔진 준비됨"
                    : "FFmpegKitNext 연결 대기"
                )
                .font(.subheadline.weight(.semibold))

                if !VideoRepairService.isAvailable {
                    Text("Mac/Xcode에서 FFmpegKitNext를 연결하면 자동 활성화됩니다.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
        }
        .foregroundStyle(.white.opacity(0.82))
    }

    private var repairModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("복구 방식", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)

            Picker("복구 방식", selection: $repairMode) {
                ForEach(VideoRepairMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(repairMode.explanation)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                repairMode == .quickRemux
                ? "빠른 복구 / 리먹스"
                : "2차 재인코딩 복구",
                systemImage: repairMode == .quickRemux
                ? "wrench.and.screwdriver"
                : "arrow.clockwise.circle"
            )
            .font(.headline)

            if repairMode == .quickRemux {
                Text("재인코딩 없이 읽을 수 있는 영상·오디오·내장 자막 스트림을 새 MKV 컨테이너에 다시 담습니다. 가능한 경우 손상 패킷을 건너뛰고 타임스탬프를 다시 만들어 재생 가능성을 높입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                Text("화질 손실이 거의 없고 빠르지만, 스트림 자체가 깨졌거나 코덱을 그대로 복사할 수 없는 경우에는 실패할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("FFmpeg가 읽을 수 있는 프레임과 오디오를 다시 디코딩한 뒤 MPEG-4 video + AAC의 새 MP4로 재인코딩합니다. 빠른 복구에서 스트림 복사가 실패한 파일을 일부 건지는 용도입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                Text("처리 시간이 오래 걸리고 화질·용량이 달라질 수 있으며, 내장 자막은 2차 복구본에 포함하지 않습니다. 이미 유실된 프레임이나 읽을 수 없는 헤더까지 되살릴 수 있는 기능은 아닙니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func failureSection(
        _ report: FFmpegFailureSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(report.title, systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(report.message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                Text("다음에 해볼 것")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Text(report.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if
                repairMode == .quickRemux,
                report.canTryReencodeRepair,
                VideoRepairService.isAvailable
            {
                Button {
                    repairMode = .reencode
                    repairVideo()
                } label: {
                    Label(
                        "2차 재인코딩 복구 시도",
                        systemImage: "arrow.clockwise.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            DisclosureGroup(
                "기술 로그 보기",
                isExpanded: $showTechnicalDetails
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(report.technicalDetails)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.6))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        UIPasteboard.general.string =
                            report.technicalDetails
                        didCopyTechnicalLog = true
                    } label: {
                        Label(
                            didCopyTechnicalLog
                            ? "복사됨"
                            : "기술 로그 복사",
                            systemImage: didCopyTechnicalLog
                            ? "checkmark"
                            : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
            .font(.subheadline)

            Text("이 분류는 FFmpeg 로그 패턴을 바탕으로 한 안내이며 파일 손상의 확정 진단은 아닙니다.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var repairButton: some View {
        Button {
            repairVideo()
        } label: {
            HStack {
                if isRepairing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(
                        systemName: repairMode == .quickRemux
                        ? "wrench.and.screwdriver"
                        : "arrow.clockwise.circle"
                    )
                }

                Text(repairButtonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.borderedProminent)
        .disabled(
            isRepairing
            || player.currentMediaURL == nil
            || !VideoRepairService.isAvailable
        )
    }

    private var repairButtonTitle: String {
        if isRepairing {
            return repairMode == .quickRemux
                ? "MKV 복구본 만드는 중…"
                : "MP4 2차 복구본 만드는 중…"
        }

        return repairMode == .quickRemux
            ? "새 MKV 복구본 만들기"
            : "2차 MP4 복구본 만들기"
    }

    private func repairVideo() {
        guard let sourceURL = player.currentMediaURL else {
            errorMessage = VideoRepairService.RepairError
                .missingSource
                .localizedDescription
            return
        }

        if player.isPlaying {
            player.togglePlayback()
        }

        cleanupRepairedOutput()
        failureSummary = nil
        showTechnicalDetails = false
        didCopyTechnicalLog = false
        isRepairing = true

        repairTask = Task {
            do {
                let url = try await VideoRepairService.repair(
                    sourceURL: sourceURL,
                    mode: repairMode
                )

                if Task.isCancelled {
                    try? FileManager.default.removeItem(
                        at: url
                    )
                    return
                }

                await MainActor.run {
                    repairedURL = url
                    isRepairing = false
                    repairTask = nil
                    showShareSheet = true
                }
            } catch let repairError as VideoRepairService.RepairError {
                let wasCancelled = Task.isCancelled

                await MainActor.run {
                    isRepairing = false
                    repairTask = nil

                    guard !wasCancelled else { return }

                    if let report =
                        repairError.failureSummary
                    {
                        failureSummary = report
                    } else {
                        errorMessage =
                            repairError.localizedDescription
                    }
                }
            } catch {
                let wasCancelled = Task.isCancelled

                await MainActor.run {
                    isRepairing = false
                    repairTask = nil

                    if !wasCancelled {
                        errorMessage =
                            error.localizedDescription
                    }
                }
            }
        }
    }

    private func cleanupRepairedOutput() {
        if let repairedURL {
            try? FileManager.default.removeItem(
                at: repairedURL
            )
        }

        repairedURL = nil
        showShareSheet = false
    }
}

private struct RepairShareSheet: UIViewControllerRepresentable {
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
