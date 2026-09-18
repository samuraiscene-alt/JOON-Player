import SwiftUI

struct MediaInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: PlayerViewModel

    @State private var snapshot: MediaInfoSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let snapshot {
                    VStack(spacing: 16) {
                        infoSection(
                            title: "파일",
                            systemImage: "doc",
                            fields: snapshot.fileFields
                        )

                        trackSection(
                            title: "비디오",
                            systemImage: "film",
                            tracks: snapshot.videoTracks
                        )

                        trackSection(
                            title: "오디오",
                            systemImage: "speaker.wave.2",
                            tracks: snapshot.audioTracks
                        )

                        trackSection(
                            title: "자막",
                            systemImage: "captions.bubble",
                            tracks: snapshot.textTracks
                        )
                    }
                    .padding(16)
                } else {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("재생 정보")
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
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        player.refreshAvailableTracks()
        snapshot = player.mediaInfoSnapshot()
    }

    private func infoSection(
        title: String,
        systemImage: String,
        fields: [MediaInfoField]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(fields) { field in
                    infoRow(field)

                    if field.id != fields.last?.id {
                        Divider()
                            .overlay(.white.opacity(0.08))
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
    }

    private func trackSection(
        title: String,
        systemImage: String,
        tracks: [MediaInfoTrack]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(tracks.count)개")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
            }

            if tracks.isEmpty {
                Text("정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.46))
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
            } else {
                VStack(spacing: 12) {
                    ForEach(tracks) { track in
                        trackCard(track)
                    }
                }
            }
        }
    }

    private func trackCard(
        _ track: MediaInfoTrack
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                if track.isSelected {
                    Text("사용 중")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            ForEach(track.fields) { field in
                infoRow(field)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private func infoRow(
        _ field: MediaInfoField
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(field.label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))
                .frame(
                    width: 76,
                    alignment: .leading
                )

            Text(field.value)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
