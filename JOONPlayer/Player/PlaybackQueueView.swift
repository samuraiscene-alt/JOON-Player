import SwiftUI

struct PlaybackQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: PlayerViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(
                        Array(player.playlistItems.enumerated()),
                        id: \.element.id
                    ) { index, item in
                        Button {
                            player.playPlaylistItem(id: item.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.08))
                                        .frame(width: 38, height: 38)

                                    if item.id == player.currentPlaylistItemID {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 14))
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.caption.monospacedDigit())
                                    }
                                }
                                .foregroundStyle(.white.opacity(0.82))

                                Text(item.fileName)
                                    .font(.subheadline.weight(
                                        item.id == player.currentPlaylistItemID
                                        ? .semibold
                                        : .regular
                                    ))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                if item.id == player.currentPlaylistItemID {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < player.playlistItems.count - 1 {
                            Divider()
                                .overlay(.white.opacity(0.08))
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(
                "재생 목록 \(player.playlistCount)개"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
