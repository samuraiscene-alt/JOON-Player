import SwiftUI

struct PlaybackControls: View {
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

    private var progressRow: some View {
        HStack(spacing: 10) {
            if player.isABRepeatActive {
                Text("A-B")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.16))
                    .clipShape(Capsule())
            }

            Text(player.formattedCurrentTime)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 46, alignment: .leading)

            Slider(
                value: Binding(
                    get: { player.currentSeconds },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.durationSeconds, 1)
            )
            .tint(.white)

            Text(player.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 46, alignment: .trailing)
        }
    }

    private var playlistRow: some View {
        HStack(spacing: 14) {
            Button {
                player.playPreviousPlaylistItem()
            } label: {
                Image(systemName: "backward.end.fill")
                    .frame(width: 36, height: 32)
            }
            .disabled(!player.canPlayPreviousPlaylistItem)
            .opacity(player.canPlayPreviousPlaylistItem ? 1 : 0.3)
            .accessibilityLabel("이전 영상")

            Spacer()

            Text(player.playlistPositionText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            Button {
                player.playNextPlaylistItem()
            } label: {
                Image(systemName: "forward.end.fill")
                    .frame(width: 36, height: 32)
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
            }

            Spacer()

            Button {
                player.seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 48, height: 48)
            }

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .frame(width: 58, height: 58)
            }

            Button {
                player.seek(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 48, height: 48)
            }

            Spacer()

            Button(action: onLockControls) {
                Image(systemName: "lock.open")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("화면 잠금")
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}
