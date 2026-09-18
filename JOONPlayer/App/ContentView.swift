import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = PlayerViewModel()
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
                        onChooseAnotherVideo: {
                            isVideoPickerPresented = true
                        },
                        onChooseSubtitle: {
                            isSubtitlePickerPresented = true
                        }
                    )
                } else {
                    EmptyPlayerView {
                        isVideoPickerPresented = true
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isVideoPickerPresented,
            allowedContentTypes: SupportedVideoTypes.all,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                player.load(url: url)

            case .failure(let error):
                player.present(error: "파일을 열 수 없습니다.\n\(error.localizedDescription)")
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
                player.present(error: "자막 파일을 열 수 없습니다.\n\(error.localizedDescription)")
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
}

private struct EmptyPlayerView: View {
    let chooseVideo: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.92))

            Text("JOON Player")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("파일 앱에 있는 동영상을 선택해 재생합니다.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)

            Button(action: chooseVideo) {
                Label("동영상 선택", systemImage: "folder")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
