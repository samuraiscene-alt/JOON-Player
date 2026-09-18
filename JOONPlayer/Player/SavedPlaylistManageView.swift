import SwiftUI

struct SavedPlaylistManageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SavedPlaylistStore
    let playlistID: UUID

    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var renameError: String?

    @State private var pendingDeleteItemIndex: Int?
    @State private var showDeletePlaylistConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let playlist = store.playlist(id: playlistID) {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard(playlist)
                            itemList(playlist)
                        }
                        .padding(16)
                    }
                } else {
                    ContentUnavailableView(
                        "재생 목록 없음",
                        systemImage: "list.bullet.rectangle",
                        description: Text(
                            "이 저장된 재생 목록은 삭제되었거나 더 이상 사용할 수 없습니다."
                        )
                    )
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(
                store.playlist(id: playlistID)?.name
                    ?? "재생 목록 관리"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if let playlist = store.playlist(
                                id: playlistID
                            ) {
                                renameText = playlist.name
                                renameError = nil
                                showRenameAlert = true
                            }
                        } label: {
                            Label(
                                "이름 변경",
                                systemImage: "character.cursor.ibeam"
                            )
                        }

                        Button(
                            role: .destructive
                        ) {
                            showDeletePlaylistConfirmation = true
                        } label: {
                            Label(
                                "재생 목록 삭제",
                                systemImage: "trash"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(
                        store.playlist(id: playlistID) == nil
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(
            "재생 목록 이름 변경",
            isPresented: $showRenameAlert
        ) {
            TextField(
                "재생 목록 이름",
                text: $renameText
            )

            Button("취소", role: .cancel) {}

            Button("변경") {
                renamePlaylist()
            }
        } message: {
            Text(
                renameError
                    ?? "같은 이름의 다른 저장 목록과는 중복할 수 없습니다."
            )
        }
        .confirmationDialog(
            "이 영상을 저장된 재생 목록에서 삭제할까요?",
            isPresented: Binding(
                get: { pendingDeleteItemIndex != nil },
                set: {
                    if !$0 {
                        pendingDeleteItemIndex = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                "목록에서 삭제",
                role: .destructive
            ) {
                deletePendingItem()
            }

            Button("취소", role: .cancel) {
                pendingDeleteItemIndex = nil
            }
        }
        .confirmationDialog(
            "저장된 재생 목록을 삭제할까요?",
            isPresented: $showDeletePlaylistConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "재생 목록 삭제",
                role: .destructive
            ) {
                store.remove(playlistID: playlistID)
                dismiss()
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("목록만 삭제하며 원본 영상 파일은 삭제하지 않습니다.")
        }
    }

    private func summaryCard(
        _ playlist: SavedPlaylistStore.Playlist
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "저장된 재생 목록",
                systemImage: "music.note.list"
            )
            .font(.headline)

            Text(playlist.name)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            Text(
                "\(playlist.items.count)개 영상 · 마지막 수정 "
                + playlist.updatedAt.formatted(
                    .dateTime
                        .month()
                        .day()
                        .hour()
                        .minute()
                )
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.52))

            Text(
                "여기서 목록 이름과 저장된 영상 항목만 관리합니다. 원본 영상 파일은 변경하거나 삭제하지 않습니다."
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.42))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private func itemList(
        _ playlist: SavedPlaylistStore.Playlist
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(
                Array(playlist.items.enumerated()),
                id: \.offset
            ) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.52))
                        .frame(width: 26)

                    Image(systemName: "film")
                        .foregroundStyle(.white.opacity(0.68))

                    Text(item.fileName)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        pendingDeleteItemIndex = index
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.52))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "저장된 재생 목록에서 영상 삭제"
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if index < playlist.items.count - 1 {
                    Divider()
                        .overlay(.white.opacity(0.08))
                        .padding(.leading, 48)
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

    private func renamePlaylist() {
        do {
            try store.rename(
                playlistID: playlistID,
                to: renameText
            )
            renameError = nil
        } catch {
            renameError = error.localizedDescription
            showRenameAlert = true
        }
    }

    private func deletePendingItem() {
        guard let index = pendingDeleteItemIndex else {
            return
        }

        pendingDeleteItemIndex = nil

        store.removeItem(
            at: index,
            from: playlistID
        )

        if store.playlist(id: playlistID) == nil {
            dismiss()
        }
    }
}
