import SwiftUI

struct PlaybackControls: View {
    @ObservedObject var player: PlayerViewModel
    let isLandscape: Bool
    @Binding var showVolumePopup: Bool

    var body: some View {
        VStack(spacing: isLandscape ? 10 : 14) {
            progressRow
            transportRow
        }
        .padding(.horizontal, isLandscape ? 18 : 14)
        .padding(.vertical, isLandscape ? 10 : 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progressRow: some View {
        HStack(spacing: 10) {
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

            Image(systemName: "lock.open")
                .font(.system(size: 19, weight: .regular))
                .frame(width: 44, height: 44)
                .foregroundStyle(.white.opacity(0.38))
                .accessibilityLabel("화면 잠금은 다음 단계에서 추가됩니다")
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}
