import SwiftUI

struct PlaybackQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: PlayerViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    playbackOptions

                    if player.isPlaylistShuffleEnabled {
                        Text("셔플이 켜진 동안에는 수동 순서 변경이 비활성화됩니다.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.48))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    queueList
                }
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

    private var playbackOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("재생 옵션", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                Button {
                    player.cyclePlaylistRepeatMode()
                } label: {
                    Label(
                        player.playlistRepeatMode.title,
                        systemImage: player.playlistRepeatMode.systemImage
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    player.togglePlaylistShuffle()
                } label: {
                    Label(
                        player.isPlaylistShuffleEnabled
                        ? "셔플 켬"
                        : "셔플 끔",
                        systemImage: "shuffle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(
                    player.isPlaylistShuffleEnabled
                    ? .white
                    : .white.opacity(0.12)
                )
                .foregroundStyle(
                    player.isPlaylistShuffleEnabled
                    ? .black
                    : .white
                )
                .disabled(player.playlistCount < 2)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private var queueList: some View {
        VStack(spacing: 0) {
            ForEach(
                Array(player.playlistItems.enumerated()),
                id: \.element.id
            ) { index, item in
                queueRow(
                    item: item,
                    index: index
                )

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
    }

    private func queueRow(
        item: PlaybackQueueItem,
        index: Int
    ) -> some View {
        HStack(spacing: 10) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !player.isPlaylistShuffleEnabled {
                VStack(spacing: 2) {
                    Button {
                        player.movePlaylistItemUp(id: item.id)
                    } label: {
                        Image(systemName: "chevron.up")
                            .frame(width: 34, height: 26)
                    }
                    .disabled(
                        !player.canMovePlaylistItemUp(id: item.id)
                    )
                    .opacity(
                        player.canMovePlaylistItemUp(id: item.id)
                        ? 1
                        : 0.22
                    )

                    Button {
                        player.movePlaylistItemDown(id: item.id)
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: 34, height: 26)
                    }
                    .disabled(
                        !player.canMovePlaylistItemDown(id: item.id)
                    )
                    .opacity(
                        player.canMovePlaylistItemDown(id: item.id)
                        ? 1
                        : 0.22
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
