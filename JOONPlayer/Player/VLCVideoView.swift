import SwiftUI
import UIKit

struct VLCVideoView: UIViewRepresentable {
    @ObservedObject var player: PlayerViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true

        DispatchQueue.main.async {
            player.attach(to: view)
            player.updateDrawableSize(view.bounds.size)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        player.attach(to: uiView)
        player.updateDrawableSize(uiView.bounds.size)
    }
}
