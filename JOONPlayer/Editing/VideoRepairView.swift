import SwiftUI
import UIKit

struct VideoRepairView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: PlayerViewModel

    @State private var isRepairing = false
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
                    explanationSection
                    engineSection

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
        .sheet(isPresented: $showShareSheet) {
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

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("빠른 복구 / 리먹스", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            Text("재인코딩 없이 읽을 수 있는 영상·오디오·내장 자막 스트림을 새 MKV 컨테이너에 다시 담습니다. 가능한 경우 손상 패킷을 건너뛰고 타임스탬프를 다시 만들어 재생 가능성을 높입니다.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Text("이미 사라진 영상 데이터나 심하게 깨진 코덱 데이터, MP4의 핵심 메타데이터가 완전히 유실된 경우까지 복원할 수 있는 기능은 아닙니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    Image(systemName: "wrench.and.screwdriver")
                }

                Text(isRepairing ? "복구본 만드는 중…" : "새 MKV 복구본 만들기")
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

        failureSummary = nil
        showTechnicalDetails = false
        didCopyTechnicalLog = false
        isRepairing = true

        Task {
            do {
                let url = try await VideoRepairService.repair(
                    sourceURL: sourceURL
                )

                await MainActor.run {
                    repairedURL = url
                    isRepairing = false
                    showShareSheet = true
                }
            } catch let repairError as VideoRepairService.RepairError {
                await MainActor.run {
                    isRepairing = false

                    if let report = repairError.failureSummary {
                        failureSummary = report
                    } else {
                        errorMessage = repairError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isRepairing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
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
