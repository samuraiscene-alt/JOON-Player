import SwiftUI
import UIKit

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
    @State private var showMediaInfo = false
    @State private var showSnapshotShareSheet = false
    @State private var snapshotURL: URL?
    @State private var isCapturingSnapshot = false
    @State private var showPlaylist = false
    @State private var isControlsLocked = false
    @State private var seekGestureFeedback: SeekGestureFeedback?
    @State private var seekFeedbackTask: Task<Void, Never>?

    @State private var horizontalSeekStartSeconds: Double?
    @State private var horizontalSeekTargetSeconds: Double?
    @State private var horizontalSeekDeltaSeconds: Double = 0
    @State private var horizontalSeekFeedbackTask: Task<Void, Never>?

    @State private var activeScreenDrag: ScreenDragMode?
    @State private var verticalAdjustmentStartValue: Double?
    @State private var verticalAdjustmentFeedback: VerticalAdjustmentFeedback?
    @State private var verticalAdjustmentFeedbackTask: Task<Void, Never>?

    @State private var temporarySpeedActivationTask: Task<Void, Never>?
    @State private var temporarySpeedTapSuppressionTask: Task<Void, Never>?
    @State private var isTemporarySpeedPressTracking = false
    @State private var temporarySpeedPressCancelled = false
    @State private var temporarySpeedPreviousRate: Float?
    @State private var isTemporaryDoubleSpeed = false
    @State private var suppressNextSingleTap = false

    @State private var autoHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoView(player: player)
                .background(Color.black)

            HardwareKeyboardShortcutReceiver(
                isEnabled: hardwareKeyboardShortcutsEnabled,
                onPlayPause: handleKeyboardPlayPause,
                onSeekBackward: {
                    handleDoubleTap(.backward)
                },
                onSeekForward: {
                    handleDoubleTap(.forward)
                },
                onVolumeUp: {
                    handleKeyboardVolumeChange(by: 0.05)
                },
                onVolumeDown: {
                    handleKeyboardVolumeChange(by: -0.05)
                },
                onToggleMute: handleKeyboardToggleMute
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)

            videoGestureLayer

            if let seekGestureFeedback {
                seekFeedbackOverlay(seekGestureFeedback)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale))
            }

            if let horizontalSeekTargetSeconds {
                horizontalSeekOverlay(
                    targetSeconds: horizontalSeekTargetSeconds,
                    deltaSeconds: horizontalSeekDeltaSeconds
                )
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale))
            }

            if let verticalAdjustmentFeedback {
                verticalAdjustmentOverlay(verticalAdjustmentFeedback)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale))
            }

            if isTemporaryDoubleSpeed {
                temporarySpeedOverlay
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

            if isCapturingSnapshot {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text("현재 장면 캡처 중…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: controlsVisible)
        .animation(.easeInOut(duration: 0.18), value: isControlsLocked)
        .animation(.easeOut(duration: 0.16), value: seekGestureFeedback)
        .animation(
            .easeOut(duration: 0.14),
            value: horizontalSeekTargetSeconds
        )
        .animation(
            .easeOut(duration: 0.14),
            value: verticalAdjustmentFeedback
        )
        .onAppear {
            scheduleAutoHideIfNeeded()
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if !isPlaying {
                endTemporaryDoubleSpeed()
            }

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
        .sheet(isPresented: $showMediaInfo) {
            MediaInfoView(player: player)
        }
        .sheet(
            isPresented: $showSnapshotShareSheet,
            onDismiss: cleanupSnapshot
        ) {
            if let snapshotURL {
                SnapshotShareSheet(
                    items: [snapshotURL]
                )
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaybackQueueView(
                player: player,
                savedPlaylistStore: savedPlaylistStore
            )
        }
        .onDisappear {
            seekFeedbackTask?.cancel()
            horizontalSeekFeedbackTask?.cancel()
            verticalAdjustmentFeedbackTask?.cancel()
            temporarySpeedTapSuppressionTask?.cancel()

            activeScreenDrag = nil
            verticalAdjustmentStartValue = nil
            verticalAdjustmentFeedback = nil
            suppressNextSingleTap = false

            cleanupSnapshot()
            endTemporaryDoubleSpeed()
            autoHideTask?.cancel()
        }
    }

    private var hardwareKeyboardShortcutsEnabled: Bool {
        player.hasMedia
            && !player.isLoading
            && !isControlsLocked
            && !showSettings
            && !showVolumePopup
            && !showTrimEditor
            && !showRepairView
            && !showMediaInfo
            && !showSnapshotShareSheet
            && !showPlaylist
            && !isCapturingSnapshot
    }

    private var videoGestureLayer: some View {
        HStack(spacing: 0) {
            gestureZone(direction: .backward)
            gestureZone(direction: .forward)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(horizontalSeekDragGesture)
        .simultaneousGesture(temporarySpeedPressGesture)
        .ignoresSafeArea()
    }

    private var horizontalSeekDragGesture: some Gesture {
        DragGesture(
            minimumDistance: PlaybackGestureTuning.horizontalSeekMinimumDistance
        )
            .onChanged { value in
                handleHorizontalSeekChanged(
                    translation: value.translation
                )
            }
            .onEnded { value in
                handleHorizontalSeekEnded(
                    translation: value.translation
                )
            }
    }

    private var temporarySpeedPressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleTemporarySpeedPressChanged(
                    translation: value.translation
                )
            }
            .onEnded { _ in
                let wasActive = isTemporaryDoubleSpeed
                endTemporaryDoubleSpeed()

                if wasActive {
                    scheduleAutoHideIfNeeded()
                }
            }
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
            .simultaneousGesture(
                verticalAdjustmentGesture(
                    for: direction == .backward
                        ? .brightness
                        : .volume
                )
            )
    }

    private func verticalAdjustmentGesture(
        for mode: ScreenDragMode
    ) -> some Gesture {
        DragGesture(
            minimumDistance: PlaybackGestureTuning.verticalMinimumDistance
        )
        .onChanged { value in
            handleVerticalAdjustmentChanged(
                mode: mode,
                translation: value.translation
            )
        }
        .onEnded { _ in
            handleVerticalAdjustmentEnded(mode: mode)
        }
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

    private func horizontalSeekOverlay(
        targetSeconds: Double,
        deltaSeconds: Double
    ) -> some View {
        VStack(spacing: 10) {
            Image(
                systemName: deltaSeconds < 0
                    ? "backward.fill"
                    : "forward.fill"
            )
            .font(.system(size: 22, weight: .semibold))

            HStack(spacing: 7) {
                Text(formatGestureTime(targetSeconds))
                    .font(.headline.monospacedDigit())

                Text("/")
                    .foregroundStyle(.white.opacity(0.4))

                Text(formatGestureTime(player.durationSeconds))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.68))
            }

            Text(formatSeekDelta(deltaSeconds))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))

            ProgressView(
                value: targetSeconds,
                total: max(player.durationSeconds, 1)
            )
            .tint(.white)
            .frame(width: 170)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func verticalAdjustmentOverlay(
        _ feedback: VerticalAdjustmentFeedback
    ) -> some View {
        HStack {
            if feedback.mode == .volume {
                Spacer()
            }

            VStack(spacing: 9) {
                Image(systemName: feedback.systemImage)
                    .font(.system(size: 27, weight: .semibold))

                Text(feedback.title)
                    .font(.caption.weight(.semibold))

                Text("\(Int((feedback.value * 100).rounded()))%")
                    .font(.headline.monospacedDigit())

                ProgressView(value: feedback.value)
                    .tint(.white)
                    .frame(width: 72)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .padding(.horizontal, isLandscape ? 70 : 28)

            if feedback.mode == .brightness {
                Spacer()
            }
        }
    }

    private var temporarySpeedOverlay: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .bold))

                Text("2×")
                    .font(.headline.weight(.bold))

                Text("길게 누르는 동안")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.top, isLandscape ? 18 : 56)
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
                    },
                    onShowMediaInfo: {
                        showSettings = false
                        showMediaInfo = true
                    },
                    onCaptureSnapshot: {
                        showSettings = false
                        captureSnapshot()
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

    private func handleTemporarySpeedPressChanged(
        translation: CGSize
    ) {
        guard !isControlsLocked else {
            endTemporaryDoubleSpeed()
            return
        }

        guard player.hasMedia, player.isPlaying else {
            endTemporaryDoubleSpeed()
            return
        }

        let distance = hypot(
            translation.width,
            translation.height
        )

        if distance > PlaybackGestureTuning.maximumPressMovement {
            temporarySpeedPressCancelled = true
            temporarySpeedActivationTask?.cancel()
            temporarySpeedActivationTask = nil

            if isTemporaryDoubleSpeed {
                endTemporaryDoubleSpeed()
            }

            return
        }

        guard !isTemporarySpeedPressTracking else {
            return
        }

        isTemporarySpeedPressTracking = true
        temporarySpeedPressCancelled = false

        temporarySpeedActivationTask?.cancel()
        temporarySpeedActivationTask = Task {
            try? await Task.sleep(
                for: .milliseconds(
                    PlaybackGestureTuning.temporarySpeedHoldMilliseconds
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard
                    isTemporarySpeedPressTracking,
                    !temporarySpeedPressCancelled,
                    !isControlsLocked,
                    player.isPlaying,
                    horizontalSeekStartSeconds == nil,
                    horizontalSeekTargetSeconds == nil,
                    activeScreenDrag == nil
                else {
                    return
                }

                beginTemporaryDoubleSpeed()
            }
        }
    }

    private func beginTemporaryDoubleSpeed() {
        guard !isTemporaryDoubleSpeed else { return }

        temporarySpeedPreviousRate = player.playbackRate
        isTemporaryDoubleSpeed = true
        suppressNextSingleTap = true

        temporarySpeedTapSuppressionTask?.cancel()

        seekFeedbackTask?.cancel()
        seekGestureFeedback = nil

        horizontalSeekFeedbackTask?.cancel()
        horizontalSeekStartSeconds = nil
        horizontalSeekTargetSeconds = nil
        horizontalSeekDeltaSeconds = 0

        player.setPlaybackRate(2.0)
        autoHideTask?.cancel()
    }

    private func endTemporaryDoubleSpeed() {
        temporarySpeedActivationTask?.cancel()
        temporarySpeedActivationTask = nil

        isTemporarySpeedPressTracking = false
        temporarySpeedPressCancelled = false

        if isTemporaryDoubleSpeed {
            if let previousRate = temporarySpeedPreviousRate {
                player.setPlaybackRate(previousRate)
            }

            isTemporaryDoubleSpeed = false

            temporarySpeedTapSuppressionTask?.cancel()
            temporarySpeedTapSuppressionTask = Task {
                try? await Task.sleep(
                    for: .milliseconds(
                        PlaybackGestureTuning.tapSuppressionMilliseconds
                    )
                )
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    suppressNextSingleTap = false
                }
            }
        } else if !isTemporarySpeedPressTracking {
            suppressNextSingleTap = false
        }

        temporarySpeedPreviousRate = nil
    }

    private func handleHorizontalSeekChanged(
        translation: CGSize
    ) {
        guard !isControlsLocked else { return }
        guard player.durationSeconds > 0 else { return }
        guard
            activeScreenDrag == nil
            || activeScreenDrag == .horizontalSeek
        else {
            return
        }

        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)

        guard horizontal > max(
            vertical * PlaybackGestureTuning.horizontalDominanceRatio,
            PlaybackGestureTuning.horizontalRecognitionThreshold
        ) else {
            return
        }

        if horizontalSeekStartSeconds == nil {
            activeScreenDrag = .horizontalSeek
            endTemporaryDoubleSpeed()
            horizontalSeekStartSeconds = player.currentSeconds
            seekGestureFeedback = nil
            seekFeedbackTask?.cancel()

            showVolumePopup = false
            showSettings = false
            autoHideTask?.cancel()
        }

        guard let startSeconds = horizontalSeekStartSeconds else {
            return
        }

        let rawDelta =
            Double(translation.width)
            * PlaybackGestureTuning.horizontalSeekSecondsPerPoint

        let target = min(
            max(startSeconds + rawDelta, 0),
            player.durationSeconds
        )

        horizontalSeekTargetSeconds = target
        horizontalSeekDeltaSeconds = target - startSeconds
    }

    private func handleHorizontalSeekEnded(
        translation: CGSize
    ) {
        guard activeScreenDrag == .horizontalSeek else {
            return
        }

        activeScreenDrag = nil

        guard
            !isControlsLocked,
            let targetSeconds = horizontalSeekTargetSeconds
        else {
            clearHorizontalSeekFeedback()
            return
        }

        player.seek(to: targetSeconds)
        horizontalSeekStartSeconds = nil

        horizontalSeekFeedbackTask?.cancel()
        horizontalSeekFeedbackTask = Task {
            try? await Task.sleep(
                for: .milliseconds(
                    PlaybackGestureTuning.horizontalSeekFeedbackMilliseconds
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                horizontalSeekTargetSeconds = nil
                horizontalSeekDeltaSeconds = 0
            }
        }

        scheduleAutoHideIfNeeded()
    }

    private func clearHorizontalSeekFeedback() {
        horizontalSeekFeedbackTask?.cancel()
        horizontalSeekStartSeconds = nil
        horizontalSeekTargetSeconds = nil
        horizontalSeekDeltaSeconds = 0
    }

    private func handleVerticalAdjustmentChanged(
        mode: ScreenDragMode,
        translation: CGSize
    ) {
        guard !isControlsLocked else { return }
        guard mode == .brightness || mode == .volume else { return }
        guard
            activeScreenDrag == nil
            || activeScreenDrag == mode
        else {
            return
        }

        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)

        guard vertical > max(
            horizontal * PlaybackGestureTuning.verticalDominanceRatio,
            PlaybackGestureTuning.verticalRecognitionThreshold
        ) else {
            return
        }

        if activeScreenDrag == nil {
            activeScreenDrag = mode
            endTemporaryDoubleSpeed()

            switch mode {
            case .brightness:
                verticalAdjustmentStartValue =
                    Double(UIScreen.main.brightness)

            case .volume:
                verticalAdjustmentStartValue = player.volume

            case .horizontalSeek:
                return
            }

            horizontalSeekFeedbackTask?.cancel()
            horizontalSeekStartSeconds = nil
            horizontalSeekTargetSeconds = nil
            horizontalSeekDeltaSeconds = 0

            seekFeedbackTask?.cancel()
            seekGestureFeedback = nil

            verticalAdjustmentFeedbackTask?.cancel()
            showVolumePopup = false
            showSettings = false
            suppressNextSingleTap = true
            autoHideTask?.cancel()
        }

        guard let startValue = verticalAdjustmentStartValue else {
            return
        }

        let delta =
            Double(-translation.height)
            * PlaybackGestureTuning.verticalValuePerPoint

        var target = startValue + delta

        if mode == .brightness {
            target = min(
                max(target, PlaybackGestureTuning.minimumBrightness),
                1
            )
            UIScreen.main.brightness = CGFloat(target)
        } else {
            target = min(max(target, 0), 1)
            player.setVolume(target)
        }

        verticalAdjustmentFeedback = VerticalAdjustmentFeedback(
            mode: mode,
            value: target
        )
    }

    private func handleVerticalAdjustmentEnded(
        mode: ScreenDragMode
    ) {
        guard activeScreenDrag == mode else { return }

        activeScreenDrag = nil
        verticalAdjustmentStartValue = nil

        verticalAdjustmentFeedbackTask?.cancel()
        verticalAdjustmentFeedbackTask = Task {
            try? await Task.sleep(
                for: .milliseconds(
                    PlaybackGestureTuning.verticalFeedbackMilliseconds
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                verticalAdjustmentFeedback = nil
            }
        }

        temporarySpeedTapSuppressionTask?.cancel()
        temporarySpeedTapSuppressionTask = Task {
            try? await Task.sleep(
                for: .milliseconds(
                    PlaybackGestureTuning.tapSuppressionMilliseconds
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                suppressNextSingleTap = false
            }
        }

        scheduleAutoHideIfNeeded()
    }

    private func handleKeyboardPlayPause() {
        guard hardwareKeyboardShortcutsEnabled else {
            return
        }

        endTemporaryDoubleSpeed()
        player.togglePlayback()
        controlsVisible = true
        scheduleAutoHideIfNeeded()
    }

    private func handleKeyboardVolumeChange(
        by delta: Double
    ) {
        guard hardwareKeyboardShortcutsEnabled else {
            return
        }

        let target = min(
            max(player.volume + delta, 0),
            1
        )

        player.setVolume(target)
        showKeyboardVolumeFeedback(
            value: target
        )
        scheduleAutoHideIfNeeded()
    }

    private func handleKeyboardToggleMute() {
        guard hardwareKeyboardShortcutsEnabled else {
            return
        }

        player.toggleMute()

        showKeyboardVolumeFeedback(
            value: player.isMuted
                ? 0
                : player.volume
        )
        scheduleAutoHideIfNeeded()
    }

    private func showKeyboardVolumeFeedback(
        value: Double
    ) {
        verticalAdjustmentFeedbackTask?.cancel()

        verticalAdjustmentFeedback =
            VerticalAdjustmentFeedback(
                mode: .volume,
                value: min(max(value, 0), 1)
            )

        verticalAdjustmentFeedbackTask = Task {
            try? await Task.sleep(
                for: .milliseconds(
                    PlaybackGestureTuning
                        .verticalFeedbackMilliseconds
                )
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                verticalAdjustmentFeedback = nil
            }
        }
    }

    private func handleSingleTap() {
        guard !isControlsLocked else { return }
        guard !isTemporaryDoubleSpeed else { return }

        if suppressNextSingleTap {
            suppressNextSingleTap = false
            temporarySpeedTapSuppressionTask?.cancel()
            temporarySpeedTapSuppressionTask = nil
            return
        }

        toggleControls()
    }

    private func handleDoubleTap(
        _ direction: SeekGestureFeedback
    ) {
        guard !isControlsLocked else { return }

        endTemporaryDoubleSpeed()

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
        horizontalSeekFeedbackTask?.cancel()
        horizontalSeekStartSeconds = nil
        horizontalSeekTargetSeconds = nil
        horizontalSeekDeltaSeconds = 0

        seekFeedbackTask?.cancel()
        seekGestureFeedback = feedback

        seekFeedbackTask = Task {
            try? await Task.sleep(
                for: .milliseconds(
                    PlaybackGestureTuning.doubleTapFeedbackMilliseconds
                )
            )
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
        showMediaInfo = false
        showSnapshotShareSheet = false
        seekFeedbackTask?.cancel()
        horizontalSeekFeedbackTask?.cancel()
        verticalAdjustmentFeedbackTask?.cancel()
        temporarySpeedTapSuppressionTask?.cancel()

        seekGestureFeedback = nil
        activeScreenDrag = nil
        verticalAdjustmentStartValue = nil
        verticalAdjustmentFeedback = nil
        suppressNextSingleTap = false

        clearHorizontalSeekFeedback()
        endTemporaryDoubleSpeed()
        autoHideTask?.cancel()
    }

    private func unlockControls() {
        isControlsLocked = false
        controlsVisible = true
        scheduleAutoHideIfNeeded()
    }

    private func captureSnapshot() {
        guard !isCapturingSnapshot else { return }

        isCapturingSnapshot = true
        snapshotURL = nil

        Task {
            do {
                let url = try await player
                    .captureCurrentFrameSnapshot()

                await MainActor.run {
                    snapshotURL = url
                    isCapturingSnapshot = false
                    showSnapshotShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isCapturingSnapshot = false
                    player.present(
                        error: error.localizedDescription
                    )
                }
            }
        }
    }

    private func cleanupSnapshot() {
        if let snapshotURL {
            try? FileManager.default.removeItem(
                at: snapshotURL
            )
        }

        snapshotURL = nil
        showSnapshotShareSheet = false
        isCapturingSnapshot = false
    }

    private func formatGestureTime(
        _ seconds: Double
    ) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00:00"
        }

        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                secs
            )
        }

        return String(
            format: "%02d:%02d",
            minutes,
            secs
        )
    }

    private func formatSeekDelta(
        _ seconds: Double
    ) -> String {
        let roundedSeconds = Int(seconds.rounded())
        return String(
            format: "%+d초",
            roundedSeconds
        )
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


private enum PlaybackGestureTuning {
    static let horizontalSeekMinimumDistance: CGFloat = 18
    static let horizontalRecognitionThreshold: CGFloat = 14
    static let horizontalDominanceRatio: CGFloat = 1.2
    static let horizontalSeekSecondsPerPoint: Double = 0.12

    static let verticalMinimumDistance: CGFloat = 18
    static let verticalRecognitionThreshold: CGFloat = 14
    static let verticalDominanceRatio: CGFloat = 1.2
    static let verticalValuePerPoint: Double = 0.0035
    static let minimumBrightness: Double = 0.01
    static let verticalFeedbackMilliseconds = 500

    static let temporarySpeedHoldMilliseconds = 350
    static let maximumPressMovement: CGFloat = 18
    static let tapSuppressionMilliseconds = 220

    static let doubleTapFeedbackMilliseconds = 650
    static let horizontalSeekFeedbackMilliseconds = 500
}

private enum ScreenDragMode: Equatable {
    case horizontalSeek
    case brightness
    case volume
}

private struct VerticalAdjustmentFeedback: Equatable {
    let mode: ScreenDragMode
    let value: Double

    var title: String {
        switch mode {
        case .brightness:
            return "밝기"
        case .volume:
            return "볼륨"
        case .horizontalSeek:
            return ""
        }
    }

    var systemImage: String {
        switch mode {
        case .brightness:
            return "sun.max.fill"
        case .volume:
            if value <= 0.001 {
                return "speaker.slash.fill"
            } else if value < 0.34 {
                return "speaker.wave.1.fill"
            } else if value < 0.67 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        case .horizontalSeek:
            return "arrow.left.and.right"
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


private struct HardwareKeyboardShortcutReceiver:
    UIViewRepresentable
{
    let isEnabled: Bool
    let onPlayPause: () -> Void
    let onSeekBackward: () -> Void
    let onSeekForward: () -> Void
    let onVolumeUp: () -> Void
    let onVolumeDown: () -> Void
    let onToggleMute: () -> Void

    func makeUIView(
        context: Context
    ) -> HardwareKeyboardResponderView {
        let view = HardwareKeyboardResponderView()

        view.configure(
            onPlayPause: onPlayPause,
            onSeekBackward: onSeekBackward,
            onSeekForward: onSeekForward,
            onVolumeUp: onVolumeUp,
            onVolumeDown: onVolumeDown,
            onToggleMute: onToggleMute
        )
        view.setShortcutEnabled(isEnabled)

        return view
    }

    func updateUIView(
        _ uiView: HardwareKeyboardResponderView,
        context: Context
    ) {
        uiView.configure(
            onPlayPause: onPlayPause,
            onSeekBackward: onSeekBackward,
            onSeekForward: onSeekForward,
            onVolumeUp: onVolumeUp,
            onVolumeDown: onVolumeDown,
            onToggleMute: onToggleMute
        )
        uiView.setShortcutEnabled(isEnabled)
    }
}

private final class HardwareKeyboardResponderView: UIView {
    private var shortcutsEnabled = false

    private var onPlayPause: (() -> Void)?
    private var onSeekBackward: (() -> Void)?
    private var onSeekForward: (() -> Void)?
    private var onVolumeUp: (() -> Void)?
    private var onVolumeDown: (() -> Void)?
    private var onToggleMute: (() -> Void)?

    override var canBecomeFirstResponder: Bool {
        true
    }

    override var keyCommands: [UIKeyCommand]? {
        guard shortcutsEnabled else {
            return []
        }

        return [
            makeCommand(
                input: " ",
                title: "재생 / 일시정지"
            ),
            makeCommand(
                input: UIKeyCommand.inputLeftArrow,
                title: "10초 뒤로"
            ),
            makeCommand(
                input: UIKeyCommand.inputRightArrow,
                title: "10초 앞으로"
            ),
            makeCommand(
                input: UIKeyCommand.inputUpArrow,
                title: "볼륨 올리기"
            ),
            makeCommand(
                input: UIKeyCommand.inputDownArrow,
                title: "볼륨 내리기"
            ),
            makeCommand(
                input: "m",
                title: "음소거 / 해제"
            )
        ]
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateFirstResponderState()
    }

    func configure(
        onPlayPause: @escaping () -> Void,
        onSeekBackward: @escaping () -> Void,
        onSeekForward: @escaping () -> Void,
        onVolumeUp: @escaping () -> Void,
        onVolumeDown: @escaping () -> Void,
        onToggleMute: @escaping () -> Void
    ) {
        self.onPlayPause = onPlayPause
        self.onSeekBackward = onSeekBackward
        self.onSeekForward = onSeekForward
        self.onVolumeUp = onVolumeUp
        self.onVolumeDown = onVolumeDown
        self.onToggleMute = onToggleMute
    }

    func setShortcutEnabled(
        _ enabled: Bool
    ) {
        guard shortcutsEnabled != enabled else {
            if enabled {
                updateFirstResponderState()
            }
            return
        }

        shortcutsEnabled = enabled
        updateFirstResponderState()
    }

    private func updateFirstResponderState() {
        if shortcutsEnabled {
            guard window != nil else { return }

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.shortcutsEnabled,
                    self.window != nil,
                    !self.isFirstResponder
                else {
                    return
                }

                _ = self.becomeFirstResponder()
            }
        } else if isFirstResponder {
            resignFirstResponder()
        }
    }

    private func makeCommand(
        input: String,
        title: String
    ) -> UIKeyCommand {
        let command = UIKeyCommand(
            input: input,
            modifierFlags: [],
            action: #selector(
                handleKeyCommand(_:)
            )
        )

        command.discoverabilityTitle = title
        command.wantsPriorityOverSystemBehavior = true

        return command
    }

    @objc
    private func handleKeyCommand(
        _ command: UIKeyCommand
    ) {
        guard shortcutsEnabled else { return }

        switch command.input {
        case " ":
            onPlayPause?()

        case UIKeyCommand.inputLeftArrow:
            onSeekBackward?()

        case UIKeyCommand.inputRightArrow:
            onSeekForward?()

        case UIKeyCommand.inputUpArrow:
            onVolumeUp?()

        case UIKeyCommand.inputDownArrow:
            onVolumeDown?()

        case "m", "M":
            onToggleMute?()

        default:
            break
        }
    }
}


private struct SnapshotShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
