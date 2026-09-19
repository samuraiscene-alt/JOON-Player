import SwiftUI
import UIKit
@preconcurrency import VLCKit

struct VLCVideoView: UIViewRepresentable {
    @ObservedObject var player: PlayerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(player: player)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true

        context.coordinator.hostView = view
        player.attach(to: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostView = uiView

        for subview in uiView.subviews {
            subview.frame = uiView.bounds
        }

        player.attach(to: context.coordinator)
        player.updateDrawableSize(uiView.bounds.size)
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var hostView: UIView?

        private let mediaPlayer: VLCMediaPlayer
        private weak var playerModel: PlayerViewModel?

        init(player: PlayerViewModel) {
            mediaPlayer = player.mediaPlayer
            playerModel = player
            super.init()
        }
    }
}

extension VLCVideoView.Coordinator: @preconcurrency VLCDrawable {
    func addSubview(_ view: UIView!) {
        guard let hostView else { return }

        view.frame = hostView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(view)
    }

    func bounds() -> CGRect {
        hostView?.bounds ?? .zero
    }
}

extension VLCVideoView.Coordinator: @preconcurrency VLCPictureInPictureDrawable {
    func mediaController() -> (any VLCPictureInPictureMediaControlling)! {
        self
    }

    func pictureInPictureReady() -> (((any VLCPictureInPictureWindowControlling)?) -> Void)! {
        { [weak self] controller in
            Task { @MainActor [weak self] in
                self?.playerModel?.registerPictureInPictureController(controller)
            }
        }
    }
}

extension VLCVideoView.Coordinator: @preconcurrency VLCPictureInPictureMediaControlling {
    func play() {
        mediaPlayer.play()
    }

    func pause() {
        mediaPlayer.pause()
    }

    func seek(by offset: Int64) async {
        let current = Int64(mediaPlayer.time.intValue)
        let length = Int64(mediaPlayer.media?.length.intValue ?? 0)
        let proposed = current + offset
        let target = length > 0
            ? min(max(proposed, 0), length)
            : max(proposed, 0)

        mediaPlayer.time = VLCTime(int: Int32(clamping: target))
    }

    func mediaLength() -> Int64 {
        Int64(mediaPlayer.media?.length.intValue ?? 0)
    }

    func mediaTime() -> Int64 {
        Int64(mediaPlayer.time.intValue)
    }

    func isMediaSeekable() -> Bool {
        mediaPlayer.isSeekable
    }

    func isMediaPlaying() -> Bool {
        mediaPlayer.isPlaying
    }
}
