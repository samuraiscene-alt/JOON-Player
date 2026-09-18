import SwiftUI

struct PlayerScreen: View {
    @ObservedObject var player: PlayerViewModel
    let isLandscape: Bool
    let onChooseAnotherVideo: () -> Void

    @State private var controlsVisible = true
    @State private var showVolumePopup = false
    @State private var showSettings = false
    @State private var autoHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoView(player: player)
                .background(Color.black)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }

            if controlsVisible {
                overlay
                    .transition(.opacity)
            }

            if player.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: controlsVisible)
        .onAppear {
            scheduleAutoHideIfNeeded()
        }
        .onChange(of: player.isPlaying) {
            scheduleAutoHideIfNeeded()
        }
        .onChange(of: isLandscape) {
            controlsVisible = true
            scheduleAutoHideIfNeeded()
        }
        .onDisappear {
            autoHideTask?.cancel()
        }
    }

    private var overlay: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, isLandscape ? 22 : 16)
                .padding(.top, 10)

            Spacer()

            if !isLandscape {
                Color.clear
                    .frame(height: 8)
            }

            PlaybackControls(
                player: player,
                isLandscape: isLandscape,
                showVolumePopup: $showVolumePopup
            )
            .padding(.horizontal, isLandscape ? 28 : 16)
            .padding(.bottom, isLandscape ? 14 : 10)
        }
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(isLandscape ? 0.5 : 0.28),
                    .clear,
                    .black.opacity(isLandscape ? 0.68 : 0.52)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .topTrailing) {
            if showSettings {
                QuickSettingsPanel(
                    player: player,
                    onChooseAnotherVideo: {
                        showSettings = false
                        onChooseAnotherVideo()
                    }
                )
                .padding(.top, 58)
                .padding(.trailing, 14)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showVolumePopup {
                VolumePopup(player: player)
                    .padding(.trailing, 18)
                    .padding(.bottom, isLandscape ? 88 : 108)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text(player.fileName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                showVolumePopup = false
                showSettings.toggle()
                keepControlsVisible()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
    }

    private func toggleControls() {
        if controlsVisible {
            controlsVisible = false
            showVolumePopup = false
            showSettings = false
            autoHideTask?.cancel()
        } else {
            controlsVisible = true
            scheduleAutoHideIfNeeded()
        }
    }

    private func keepControlsVisible() {
        controlsVisible = true
        autoHideTask?.cancel()
    }

    private func scheduleAutoHideIfNeeded() {
        autoHideTask?.cancel()

        guard isLandscape, player.isPlaying, !showSettings, !showVolumePopup else {
            return
        }

        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                controlsVisible = false
            }
        }
    }
}
