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
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        player.attach(to: uiView)
    }
}
