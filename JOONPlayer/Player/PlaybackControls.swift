import SwiftUI

struct PlaybackControls: View {
    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @ObservedObject var player: PlayerViewModel
    let isLandscape: Bool
    @Binding var showVolumePopup: Bool
    let onLockControls: () -> Void

    var body: some View {
        VStack(spacing: isLandscape ? 10 : 14) {
            progressRow

            if player.playlistCount > 1 {
                playlistRow
            }

            transportRow
        }
        .padding(.horizontal, isLandscape ? 18 : 14)
        .padding(.vertical, isLandscape ? 10 : 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var progressRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    playbackStatusIndicators

                    Spacer()

                    Text(player.formattedCurrentTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.78))
                        .accessibilityHidden(true)

                    Text("/")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                        .accessibilityHidden(true)

                    Text(player.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.78))
                        .accessibilityHidden(true)
                }

                progressSlider
            }
        } else {
            HStack(spacing: 10) {
                playbackStatusIndicators

                Text(player.formattedCurrentTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 46, alignment: .leading)
                    .accessibilityHidden(true)

                progressSlider

                Text(player.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 46, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
    }

    private var playbackStatusIndicators: some View {
        HStack(spacing: 6) {
            if player.isABRepeatActive {
                Text("A-B")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.16))
                    .clipShape(Capsule())
                    .accessibilityLabel("A-B 반복 활성화")
            }

            if player.sleepTimerMode != .off {
                Image(systemName: "moon.zzz.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.82))
                    .accessibilityLabel("취침 타이머 활성화")
                    .accessibilityValue(
                        player.sleepTimerStatusText
                    )
            }
        }
    }

    private var progressSlider: some View {
        Slider(
            value: Binding(
                get: { player.currentSeconds },
                set: { player.seek(to: $0) }
            ),
            in: 0...max(player.durationSeconds, 1)
        )
        .tint(.white)
        .accessibilityLabel("재생 위치")
        .accessibilityValue(
            "\(player.formattedCurrentTime), 전체 \(player.formattedDuration)"
        )
        .accessibilityHint("위아래로 쓸어 재생 위치를 조절합니다.")
    }

    private var playlistRow: some View {
        HStack(spacing: 14) {
            Button {
                player.playPreviousPlaylistItem()
            } label: {
                Image(systemName: "backward.end.fill")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!player.canPlayPreviousPlaylistItem)
            .opacity(player.canPlayPreviousPlaylistItem ? 1 : 0.3)
            .accessibilityLabel("이전 영상")

            Spacer()

            Text(player.playlistPositionText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityLabel(
                    "재생 목록 위치 \(player.playlistPositionText)"
                )

            Spacer()

            Button {
                player.playNextPlaylistItem()
            } label: {
                Image(systemName: "forward.end.fill")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!player.canPlayNextPlaylistItem)
            .opacity(player.canPlayNextPlaylistItem ? 1 : 0.3)
            .accessibilityLabel("다음 영상")
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var transportRow: some View {
        HStack {
            Button {
                showVolumePopup.toggle()
            } label: {
                Image(systemName: player.isMuted ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("볼륨 조절")
            .accessibilityValue(
                player.isMuted
                ? "음소거"
                : "\(Int((player.volume * 100).rounded()))%"
            )
            .accessibilityHint("볼륨 조절 팝업을 엽니다.")

            Spacer()

            Button {
                player.seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("10초 뒤로")

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .frame(width: 58, height: 58)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(
                player.isPlaying
                ? "일시정지"
                : "재생"
            )

            Button {
                player.seek(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("10초 앞으로")

            Spacer()

            Button(action: onLockControls) {
                Image(systemName: "lock.open")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("화면 잠금")
            .accessibilityHint("터치 제스처와 재생 컨트롤을 잠급니다.")
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}
