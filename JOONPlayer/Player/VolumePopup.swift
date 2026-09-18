import SwiftUI

struct VolumePopup: View {
    @ObservedObject var player: PlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.toggleMute()
            } label: {
                Image(systemName: player.isMuted ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { player.isMuted ? 0 : player.volume },
                    set: { player.setVolume($0) }
                ),
                in: 0...1
            )
            .tint(.white)
            .frame(width: 150)

            Text("\(Int((player.isMuted ? 0 : player.volume) * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 38, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
