import SwiftUI

struct PlayerScreen: View {
    @ObservedObject var player: PlayerViewModel
    @ObservedObject var savedPlaylistStore: SavedPlaylistStore
    let isLandscape: Bool
    let onCloseVideo: () -> Void
    let onChooseAnotherVideo: () -> Void
    let onChooseSubtitle: () -> Void

    @State private var controlsVisible = true
    @State private var showVolumePopup = false
    @State private var showSettings = false
    @State private var showTrimEditor = false
    @State private var showRepairView = false
    @State private var showPlaylist = false
    @State private var isControlsLocked = false
    @State private var seekGestureFeedback: SeekGestureFeedback?
    @State private var seekFeedbackTask: Task<Void, Never>?
    @State private var autoHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoView(player: player)
                .background(Color.black)

            videoGestureLayer

            if let seekGestureFeedback {
                seekFeedbackOverlay(seekGestureFeedback)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale))
            }

            if isControlsLocked {
                lockedOverlay
                    .transition(.opacity)
            } else if controlsVisible {
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
        .animation(.easeInOut(duration: 0.18), value: isControlsLocked)
        .animation(.easeOut(duration: 0.16), value: seekGestureFeedback)
        .onAppear {
            scheduleAutoHideIfNeeded()
        }
        .onChange(of: player.isPlaying) {
            scheduleAutoHideIfNeeded()
        }
        .onChange(of: isLandscape) {
            if !isControlsLocked {
                controlsVisible = true
            }
            scheduleAutoHideIfNeeded()
        }
        .sheet(isPresented: $showTrimEditor) {
            TrimEditorView(player: player)
        }
        .sheet(isPresented: $showRepairView) {
            VideoRepairView(player: player)
        }
        .sheet(isPresented: $showPlaylist) {
            PlaybackQueueView(
                player: player,
                savedPlaylistStore: savedPlaylistStore
            )
        }
        .onDisappear {
            seekFeedbackTask?.cancel()
            autoHideTask?.cancel()
        }
    }

    private var videoGestureLayer: some View {
        HStack(spacing: 0) {
            gestureZone(direction: .backward)
            gestureZone(direction: .forward)
        }
        .ignoresSafeArea()
    }

    private func gestureZone(
        direction: SeekGestureFeedback
    ) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        handleDoubleTap(direction)
                    }
                    .exclusively(
                        before: TapGesture(count: 1)
                            .onEnded {
                                handleSingleTap()
                            }
                    )
            )
    }

    private func seekFeedbackOverlay(
        _ feedback: SeekGestureFeedback
    ) -> some View {
        HStack {
            if feedback == .forward {
                Spacer()
            }

            VStack(spacing: 6) {
                Image(systemName: feedback.systemImage)
                    .font(.system(size: 30, weight: .semibold))

                Text(feedback.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 92, height: 92)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .padding(.horizontal, isLandscape ? 70 : 34)

            if feedback == .backward {
                Spacer()
            }
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
                showVolumePopup: $showVolumePopup,
                onLockControls: lockControls
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
                    },
                    onChooseSubtitle: {
                        showSettings = false
                        onChooseSubtitle()
                    },
                    onRepairVideo: {
                        showSettings = false
                        showRepairView = true
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

    private var lockedOverlay: some View {
        VStack {
            Spacer()

            HStack {
                Button(action: unlockControls) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("화면 잠금 해제")

                Spacer()
            }
            .padding(.horizontal, isLandscape ? 24 : 18)
            .padding(.bottom, isLandscape ? 18 : 16)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                showVolumePopup = false
                showSettings = false
                onCloseVideo()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("최근 파일 화면으로 돌아가기")

            Text(player.fileName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if player.playlistCount > 1 {
                Button {
                    showVolumePopup = false
                    showSettings = false
                    keepControlsVisible()
                    showPlaylist = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("재생 목록")
            }

            Button {
                showVolumePopup = false
                showSettings = false
                keepControlsVisible()
                showTrimEditor = true
            } label: {
                Image(systemName: "scissors")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(player.durationSeconds <= 0)
            .opacity(player.durationSeconds > 0 ? 1 : 0.35)
            .accessibilityLabel("영상 자르기")

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

    private func handleSingleTap() {
        guard !isControlsLocked else { return }
        toggleControls()
    }

    private func handleDoubleTap(
        _ direction: SeekGestureFeedback
    ) {
        guard !isControlsLocked else { return }

        switch direction {
        case .backward:
            player.seek(by: -10)

        case .forward:
            player.seek(by: 10)
        }

        showSeekFeedback(direction)
        scheduleAutoHideIfNeeded()
    }

    private func showSeekFeedback(
        _ feedback: SeekGestureFeedback
    ) {
        seekFeedbackTask?.cancel()
        seekGestureFeedback = feedback

        seekFeedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                seekGestureFeedback = nil
            }
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

    private func lockControls() {
        isControlsLocked = true
        controlsVisible = false
        showVolumePopup = false
        showSettings = false
        showPlaylist = false
        autoHideTask?.cancel()
    }

    private func unlockControls() {
        isControlsLocked = false
        controlsVisible = true
        scheduleAutoHideIfNeeded()
    }

    private func scheduleAutoHideIfNeeded() {
        autoHideTask?.cancel()

        guard
            !isControlsLocked,
            isLandscape,
            player.isPlaying,
            !showSettings,
            !showVolumePopup
        else {
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


private enum SeekGestureFeedback: Equatable {
    case backward
    case forward

    var systemImage: String {
        switch self {
        case .backward:
            return "gobackward.10"
        case .forward:
            return "goforward.10"
        }
    }

    var label: String {
        switch self {
        case .backward:
            return "-10초"
        case .forward:
            return "+10초"
        }
    }
}
