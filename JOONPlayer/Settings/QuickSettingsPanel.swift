import SwiftUI

struct QuickSettingsPanel: View {
    @ObservedObject var player: PlayerViewModel
    let onChooseAnotherVideo: () -> Void

    private let rates: [Float] = [0.5, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("빠른 설정")
                .font(.headline)
                .foregroundStyle(.white)

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

            Divider()
                .overlay(.white.opacity(0.12))

            Button(action: onChooseAnotherVideo) {
                Label("다른 동영상 열기", systemImage: "folder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            disabledRow(title: "자막", icon: "captions.bubble")
            disabledRow(title: "화면비율", icon: "aspectratio")
            disabledRow(title: "PiP", icon: "pip")
        }
        .padding(16)
        .frame(maxWidth: 330)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func disabledRow(title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("다음 단계")
                .font(.caption)
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.38))
    }

    private func rateLabel(_ rate: Float) -> String {
        rate == 1.0 ? "1x" : "\(rate.formatted(.number.precision(.fractionLength(0...2))))x"
    }
}
