import SwiftUI

struct QuickSettingsPanel: View {
    @ObservedObject var player: PlayerViewModel
    let onChooseAnotherVideo: () -> Void
    let onChooseSubtitle: () -> Void
    let onRepairVideo: () -> Void

    private let rates: [Float] = [0.5, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("빠른 설정")
                    .font(.headline)
                    .foregroundStyle(.white)

                playbackRateSection

                Divider()
                    .overlay(.white.opacity(0.12))

                abRepeatSection

                Divider()
                    .overlay(.white.opacity(0.12))

                sleepTimerSection

                Divider()
                    .overlay(.white.opacity(0.12))

                videoDisplaySection

                Divider()
                    .overlay(.white.opacity(0.12))

                subtitleSection

                Divider()
                    .overlay(.white.opacity(0.12))

                pictureInPictureRow

                Divider()
                    .overlay(.white.opacity(0.12))

                repairRow

                Divider()
                    .overlay(.white.opacity(0.12))

                Button(action: onChooseAnotherVideo) {
                    Label("다른 동영상 열기", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(16)
        }
        .frame(maxWidth: 330, maxHeight: 520)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var playbackRateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("재생 속도", systemImage: "speedometer")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 7) {
                ForEach(rates, id: \.self) { rate in
                    Button {
                        player.setPlaybackRate(rate)
                    } label: {
                        Text(rateLabel(rate))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                player.playbackRate == rate
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.playbackRate == rate
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var abRepeatSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("A-B 반복", systemImage: "repeat")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if player.isABRepeatActive {
                    Text("반복 중")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                Button {
                    player.markABRepeatStart()
                } label: {
                    VStack(spacing: 2) {
                        Text("A 설정")
                            .font(.caption.weight(.semibold))

                        Text(player.formattedABRepeatStart)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    player.markABRepeatEnd()
                } label: {
                    VStack(spacing: 2) {
                        Text("B 설정")
                            .font(.caption.weight(.semibold))

                        Text(player.formattedABRepeatEnd)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!player.canSetABRepeatEnd)
                .opacity(player.canSetABRepeatEnd ? 1 : 0.4)

                Button {
                    player.clearABRepeat()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .disabled(player.abRepeatStartSeconds == nil)
                .opacity(
                    player.abRepeatStartSeconds == nil
                    ? 0.4
                    : 1
                )
                .accessibilityLabel("A-B 반복 해제")
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.82))

            Text(
                player.isABRepeatActive
                ? "B 지점에 도달하면 A 지점으로 돌아갑니다."
                : "A를 먼저 정한 뒤 원하는 위치에서 B를 설정합니다."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("취침 타이머", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if player.sleepTimerMode != .off {
                    Text(player.sleepTimerStatusText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            HStack(spacing: 7) {
                ForEach(
                    [
                        SleepTimerMode.minutes15,
                        .minutes30,
                        .minutes60,
                        .endOfCurrentVideo
                    ]
                ) { mode in
                    Button {
                        player.setSleepTimer(mode)
                    } label: {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                player.sleepTimerMode == mode
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.sleepTimerMode == mode
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if player.sleepTimerMode != .off {
                Button {
                    player.clearSleepTimer()
                } label: {
                    Label("타이머 해제", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private var videoDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("화면비율", systemImage: "aspectratio")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 7) {
                ForEach(VideoDisplayMode.allCases) { mode in
                    Button {
                        player.setVideoDisplayMode(mode)
                    } label: {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                player.videoDisplayMode == mode
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.videoDisplayMode == mode
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var subtitleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("외부 자막", systemImage: "captions.bubble")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if player.subtitleWasAutoLoaded {
                    Text("자동")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let subtitleName = player.subtitleName {
                Text(subtitleName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            } else {
                Text("연결된 SRT 자막 없음")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Button(action: onChooseSubtitle) {
                Label("SRT 파일 선택", systemImage: "doc.badge.plus")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            if player.subtitleName != nil {
                subtitleDelayControls
                subtitleSizeControls
                subtitlePositionControls
            }
        }
    }

    private var subtitleDelayControls: some View {
        HStack(spacing: 8) {
            Text("싱크")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 34, alignment: .leading)

            Button {
                player.adjustSubtitleDelay(byMilliseconds: -100)
            } label: {
                Text("-0.1")
                    .frame(minWidth: 42)
            }

            Button {
                player.resetSubtitleDelay()
            } label: {
                Text(player.formattedSubtitleDelay)
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 62)
            }

            Button {
                player.adjustSubtitleDelay(byMilliseconds: 100)
            } label: {
                Text("+0.1")
                    .frame(minWidth: 42)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.82))
    }

    private var subtitleSizeControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "textformat.size")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 34)

            Button {
                player.adjustSubtitleFontScale(by: -0.1)
            } label: {
                Image(systemName: "minus")
                    .frame(minWidth: 42)
            }
            .disabled(player.subtitleFontScale <= 0.6)

            Button {
                player.resetSubtitleFontScale()
            } label: {
                Text(player.formattedSubtitleFontScale)
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 62)
            }

            Button {
                player.adjustSubtitleFontScale(by: 0.1)
            } label: {
                Image(systemName: "plus")
                    .frame(minWidth: 42)
            }
            .disabled(player.subtitleFontScale >= 1.8)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.82))
    }

    private var subtitlePositionControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("자막 위치", systemImage: "arrow.up.and.down")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            HStack(spacing: 7) {
                ForEach(SubtitleVerticalPosition.allCases) { position in
                    Button {
                        player.setSubtitleVerticalPosition(position)
                    } label: {
                        Text(position.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                player.subtitleVerticalPosition == position
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.subtitleVerticalPosition == position
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pictureInPictureRow: some View {
        Button {
            player.togglePictureInPicture()
        } label: {
            HStack {
                Label(
                    player.isPictureInPictureActive ? "PiP 종료" : "PiP 시작",
                    systemImage: player.isPictureInPictureActive ? "pip.exit" : "pip.enter"
                )

                Spacer()

                if !player.isPictureInPictureReady {
                    Text("준비 중")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(!player.isPictureInPictureReady)
        .opacity(player.isPictureInPictureReady ? 1 : 0.45)
    }

    private var repairRow: some View {
        Button(action: onRepairVideo) {
            HStack {
                Label("영상 복구 / 리먹스", systemImage: "wrench.and.screwdriver")

                Spacer()

                Text(
                    VideoRepairService.isAvailable
                    ? "준비됨"
                    : "연결 대기"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func rateLabel(_ rate: Float) -> String {
        rate == 1.0 ? "1x" : "\(rate.formatted(.number.precision(.fractionLength(0...2))))x"
    }
}
