import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var player = PlayerViewModel()
    @StateObject private var recentStore = RecentMediaStore()

    @State private var isVideoPickerPresented = false
    @State private var isSubtitlePickerPresented = false

    private var srtType: UTType {
        UTType(filenameExtension: "srt") ?? .plainText
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                if player.hasMedia {
                    PlayerScreen(
                        player: player,
                        isLandscape: isLandscape,
                        onCloseVideo: {
                            player.closeMedia()
                        },
                        onChooseAnotherVideo: {
                            isVideoPickerPresented = true
                        },
                        onChooseSubtitle: {
                            isSubtitlePickerPresented = true
                        }
                    )
                } else {
                    EmptyPlayerView(
                        recentItems: recentStore.items,
                        chooseVideo: {
                            isVideoPickerPresented = true
                        },
                        openRecent: openRecent,
                        removeRecent: { item in
                            recentStore.remove(item)
                        },
                        clearRecent: {
                            recentStore.removeAll()
                        }
                    )
                }
            }
        }
        .fileImporter(
            isPresented: $isVideoPickerPresented,
            allowedContentTypes: SupportedVideoTypes.all,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }

                for url in urls.reversed() {
                    try? recentStore.remember(url: url)
                }

                if urls.count == 1, let url = urls.first {
                    player.load(url: url)
                } else {
                    player.loadPlaylist(urls: urls)
                }

            case .failure(let error):
                player.present(
                    error: "파일을 열 수 없습니다.\n\(error.localizedDescription)"
                )
            }
        }
        .fileImporter(
            isPresented: $isSubtitlePickerPresented,
            allowedContentTypes: [srtType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                player.loadSubtitle(url: url)

            case .failure(let error):
                player.present(
                    error: "자막 파일을 열 수 없습니다.\n\(error.localizedDescription)"
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                player.persistPlaybackProgress()
            }
        }
        .alert(
            "JOON Player",
            isPresented: Binding(
                get: { player.errorMessage != nil },
                set: { if !$0 { player.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {
                player.errorMessage = nil
            }
        } message: {
            Text(player.errorMessage ?? "")
        }
    }

    private func openRecent(_ item: RecentMediaStore.Item) {
        do {
            let url = try recentStore.resolve(item)
            player.load(url: url)
        } catch {
            player.present(error: error.localizedDescription)
        }
    }
}

private struct EmptyPlayerView: View {
    let recentItems: [RecentMediaStore.Item]
    let chooseVideo: () -> Void
    let openRecent: (RecentMediaStore.Item) -> Void
    let removeRecent: (RecentMediaStore.Item) -> Void
    let clearRecent: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                Button(action: chooseVideo) {
                    Label("동영상 선택", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                if !recentItems.isEmpty {
                    recentSection
                }
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.92))

            Text("JOON Player")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("파일 앱에서 한 개 또는 여러 영상을 선택하거나 최근 파일에서 바로 이어서 재생합니다.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("최근 파일", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button("모두 지우기", action: clearRecent)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(recentItems.enumerated()), id: \.element.id) {
                    index,
                    item in

                    HStack(spacing: 12) {
                        Button {
                            openRecent(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "film")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.fileName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Text(
                                        item.lastOpenedAt,
                                        format: .dateTime
                                            .month()
                                            .day()
                                            .hour()
                                            .minute()
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.46))
                                }

                                Spacer()

                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            removeRecent(item)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.48))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("최근 파일에서 삭제")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if index < recentItems.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.08))
                            .padding(.leading, 54)
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
}
