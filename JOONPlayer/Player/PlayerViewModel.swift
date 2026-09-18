import AVFoundation
import Foundation
import UIKit
import VLCKit

enum VideoDisplayMode: String, CaseIterable, Identifiable {
    case original
    case fit
    case fill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "원본"
        case .fit:
            return "화면 맞춤"
        case .fill:
            return "화면 채우기"
        }
    }
}

enum SubtitleVerticalPosition: String, CaseIterable, Identifiable {
    case standard
    case raised
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "기본"
        case .raised:
            return "위로"
        case .high:
            return "더 위로"
        }
    }

    var bottomMargin: Int {
        switch self {
        case .standard:
            return 0
        case .raised:
            return 60
        case .high:
            return 120
        }
    }
}

@MainActor
final class PlayerViewModel: NSObject, ObservableObject {
    @Published var hasMedia = false
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentSeconds: Double = 0
    @Published var durationSeconds: Double = 0
    @Published var errorMessage: String?
    @Published var fileName = ""

    @Published var volume: Double = 1.0
    @Published var isMuted = false
    @Published var playbackRate: Float = 1.0
    @Published var videoDisplayMode: VideoDisplayMode = .original

    @Published var subtitleName: String?
    @Published var subtitleWasAutoLoaded = false
    @Published var subtitleDelayMilliseconds = 0
    @Published var subtitleFontScale: Float = 1.0
    @Published var subtitleVerticalPosition: SubtitleVerticalPosition = .standard

    @Published var isPictureInPictureReady = false
    @Published var isPictureInPictureActive = false

    let mediaPlayer = VLCMediaPlayer()

    private var securityScopedURL: URL?
    private var isUsingSecurityScope = false
    private var lastNonZeroVolume: Double = 1.0
    private var drawableSize: CGSize = .zero

    private var subtitleURL: URL?
    private var isUsingSubtitleScope = false
    private var subtitleNeedsAttach = false
    private var pendingSubtitleIsAutomatic = false

    private var pictureInPictureController: (any VLCPictureInPictureWindowControlling)?

    private let resumeStore = PlaybackResumeStore.shared
    private var currentResumeIdentifier: String?
    private var pendingResumeSeconds: Double?
    private var lastSavedResumeSecond = -1

    private var pendingSubtitlePositionRestartSeconds: Double?
    private var shouldResumeAfterSubtitlePositionRestart = true

    private enum PreferenceKey {
        static let subtitleFontScale = "joonplayer.subtitle.fontScale"
        static let subtitleVerticalPosition = "joonplayer.subtitle.verticalPosition"
    }

    override init() {
        super.init()

        let defaults = UserDefaults.standard

        if let savedScale = defaults.object(
            forKey: PreferenceKey.subtitleFontScale
        ) as? NSNumber {
            subtitleFontScale = min(max(savedScale.floatValue, 0.6), 1.8)
        }

        if
            let rawPosition = defaults.string(
                forKey: PreferenceKey.subtitleVerticalPosition
            ),
            let savedPosition = SubtitleVerticalPosition(rawValue: rawPosition)
        {
            subtitleVerticalPosition = savedPosition
        }

        mediaPlayer.delegate = self
        mediaPlayer.currentSubTitleFontScale = subtitleFontScale
        configureAudioSession()
    }

    deinit {
        mediaPlayer.stop()
        releaseSubtitleScope()
        releaseSecurityScope()
    }

    func attach(to drawable: AnyObject) {
        mediaPlayer.drawable = drawable
    }

    func updateDrawableSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        let widthChanged = abs(drawableSize.width - size.width) > 0.5
        let heightChanged = abs(drawableSize.height - size.height) > 0.5

        guard widthChanged || heightChanged else { return }

        drawableSize = size
        applyVideoDisplayMode()
    }

    func registerPictureInPictureController(
        _ controller: (any VLCPictureInPictureWindowControlling)?
    ) {
        pictureInPictureController = controller
        isPictureInPictureReady = controller != nil

        controller?.stateChangeEventHandler = { [weak self] isStarted in
            Task { @MainActor in
                self?.isPictureInPictureActive = isStarted
            }
        }
    }

    func togglePictureInPicture() {
        guard let pictureInPictureController else {
            errorMessage = "PiP가 아직 준비되지 않았습니다."
            return
        }

        if isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        } else {
            pictureInPictureController.startPictureInPicture()
        }
    }

    func load(url: URL) {
        persistPlaybackProgress()
        mediaPlayer.stop()
        releaseSubtitleScope()
        releaseSecurityScope()

        securityScopedURL = url
        isUsingSecurityScope = url.startAccessingSecurityScopedResource()

        currentResumeIdentifier = PlaybackResumeStore.identifier(for: url)
        pendingResumeSeconds = currentResumeIdentifier.flatMap {
            resumeStore.position(for: $0)
        }
        lastSavedResumeSecond = -1

        hasMedia = true
        isLoading = true
        isPlaying = false
        currentSeconds = 0
        durationSeconds = 0
        errorMessage = nil
        fileName = url.lastPathComponent

        subtitleName = nil
        subtitleWasAutoLoaded = false
        subtitleDelayMilliseconds = 0
        pendingSubtitlePositionRestartSeconds = nil

        mediaPlayer.media = makeMedia(url: url)
        mediaPlayer.rate = playbackRate
        mediaPlayer.currentSubTitleFontScale = subtitleFontScale

        if let automaticSubtitle = findAutomaticSubtitle(for: url) {
            queueSubtitle(url: automaticSubtitle, isAutomatic: true)
        }

        configureAudioSession()
        applyVolumeToEngine()
        applyVideoDisplayMode()
        mediaPlayer.play()
    }

    func closeMedia() {
        persistPlaybackProgress()

        if isPictureInPictureActive {
            pictureInPictureController?.stopPictureInPicture()
        }

        mediaPlayer.stop()
        releaseSubtitleScope()
        releaseSecurityScope()

        currentResumeIdentifier = nil
        pendingResumeSeconds = nil
        lastSavedResumeSecond = -1

        pictureInPictureController = nil
        isPictureInPictureReady = false
        isPictureInPictureActive = false

        hasMedia = false
        isPlaying = false
        isLoading = false
        currentSeconds = 0
        durationSeconds = 0
        fileName = ""

        subtitleName = nil
        subtitleWasAutoLoaded = false
        subtitleDelayMilliseconds = 0
        pendingSubtitlePositionRestartSeconds = nil
    }

    func togglePlayback() {
        guard hasMedia else { return }

        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    func seek(by seconds: Double) {
        seek(to: currentSeconds + seconds)
    }

    func seek(to seconds: Double) {
        guard hasMedia else { return }

        let upperBound = durationSeconds > 0 ? durationSeconds : max(seconds, 0)
        let target = min(max(seconds, 0), upperBound)

        mediaPlayer.time = VLCTime(int: Int32(target * 1000))
        currentSeconds = target
    }

    func setVolume(_ newValue: Double) {
        let clamped = min(max(newValue, 0), 1)
        volume = clamped

        if clamped > 0 {
            lastNonZeroVolume = clamped
            isMuted = false
        } else {
            isMuted = true
        }

        applyVolumeToEngine()
    }

    func toggleMute() {
        if isMuted {
            isMuted = false
            volume = max(lastNonZeroVolume, 0.01)
        } else {
            if volume > 0 {
                lastNonZeroVolume = volume
            }
            isMuted = true
        }

        applyVolumeToEngine()
    }

    func setPlaybackRate(_ rate: Float) {
        let clamped = min(max(rate, 0.5), 2.0)
        playbackRate = clamped
        mediaPlayer.rate = clamped
    }

    func setVideoDisplayMode(_ mode: VideoDisplayMode) {
        videoDisplayMode = mode
        applyVideoDisplayMode()
    }

    func loadSubtitle(url: URL) {
        guard hasMedia else {
            errorMessage = "동영상을 먼저 연 뒤 자막을 선택해 주세요."
            return
        }

        queueSubtitle(url: url, isAutomatic: false)
        attachPendingSubtitleIfPossible()
    }

    func adjustSubtitleDelay(byMilliseconds delta: Int) {
        setSubtitleDelay(milliseconds: subtitleDelayMilliseconds + delta)
    }

    func resetSubtitleDelay() {
        setSubtitleDelay(milliseconds: 0)
    }

    func setSubtitleDelay(milliseconds: Int) {
        let clamped = min(max(milliseconds, -10_000), 10_000)
        subtitleDelayMilliseconds = clamped
        mediaPlayer.currentVideoSubTitleDelay = clamped * 1_000
    }

    func adjustSubtitleFontScale(by delta: Float) {
        setSubtitleFontScale(subtitleFontScale + delta)
    }

    func resetSubtitleFontScale() {
        setSubtitleFontScale(1.0)
    }

    func setSubtitleFontScale(_ scale: Float) {
        let clamped = min(max(scale, 0.6), 1.8)
        let rounded = (clamped * 10).rounded() / 10

        subtitleFontScale = rounded
        mediaPlayer.currentSubTitleFontScale = rounded

        UserDefaults.standard.set(
            rounded,
            forKey: PreferenceKey.subtitleFontScale
        )
    }

    func setSubtitleVerticalPosition(_ position: SubtitleVerticalPosition) {
        guard subtitleVerticalPosition != position else { return }

        subtitleVerticalPosition = position
        UserDefaults.standard.set(
            position.rawValue,
            forKey: PreferenceKey.subtitleVerticalPosition
        )

        restartMediaForSubtitlePositionIfNeeded()
    }

    func persistPlaybackProgress() {
        guard
            let currentResumeIdentifier,
            durationSeconds > 0
        else {
            return
        }

        resumeStore.save(
            position: currentSeconds,
            duration: durationSeconds,
            for: currentResumeIdentifier
        )

        lastSavedResumeSecond = Int(currentSeconds.rounded(.down))
    }

    func present(error: String) {
        errorMessage = error
    }

    var currentMediaURL: URL? {
        securityScopedURL
    }

    var formattedCurrentTime: String {
        Self.formatTime(currentSeconds)
    }

    var formattedDuration: String {
        Self.formatTime(durationSeconds)
    }

    var formattedSubtitleDelay: String {
        let seconds = Double(subtitleDelayMilliseconds) / 1000.0

        if subtitleDelayMilliseconds == 0 {
            return "0.0초"
        }

        return String(format: "%+.1f초", seconds)
    }

    var formattedSubtitleFontScale: String {
        "\(Int((subtitleFontScale * 100).rounded()))%"
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            // PiP/백그라운드 오디오 설정 실패가 영상 재생 자체를 막지는 않게 둔다.
        }
    }

    private func makeMedia(url: URL) -> VLCMedia {
        let media = VLCMedia(url: url)
        media.addOption(
            ":sub-margin=\(subtitleVerticalPosition.bottomMargin)"
        )
        return media
    }

    private func applyVolumeToEngine() {
        let effectiveVolume = isMuted ? 0 : volume
        mediaPlayer.audio.isMuted = isMuted
        mediaPlayer.audio.volume = Int32((effectiveVolume * 100).rounded())
    }

    private func applyVideoDisplayMode() {
        mediaPlayer.scaleFactor = 0

        switch videoDisplayMode {
        case .original:
            mediaPlayer.videoAspectRatio = nil
            mediaPlayer.videoFitMode = .smaller

        case .fit:
            guard drawableSize.width > 0, drawableSize.height > 0 else { return }

            let width = max(Int(drawableSize.width.rounded()), 1)
            let height = max(Int(drawableSize.height.rounded()), 1)

            mediaPlayer.videoAspectRatio = "\(width):\(height)"
            mediaPlayer.videoFitMode = .smaller

        case .fill:
            mediaPlayer.videoAspectRatio = nil
            mediaPlayer.videoFitMode = .larger
        }
    }

    private func invalidatePictureInPicturePlaybackState() {
        pictureInPictureController?.invalidatePlaybackState()
    }

    private func restartMediaForSubtitlePositionIfNeeded() {
        guard
            hasMedia,
            subtitleName != nil,
            let videoURL = securityScopedURL
        else {
            return
        }

        pendingSubtitlePositionRestartSeconds = currentSeconds
        shouldResumeAfterSubtitlePositionRestart = isPlaying

        if subtitleURL != nil {
            subtitleNeedsAttach = true
        }

        isLoading = true
        mediaPlayer.stop()
        mediaPlayer.media = makeMedia(url: videoURL)
        mediaPlayer.rate = playbackRate
        mediaPlayer.currentSubTitleFontScale = subtitleFontScale
        applyVolumeToEngine()
        applyVideoDisplayMode()
        mediaPlayer.play()
    }

    private func applyPendingSubtitlePositionRestartIfPossible() {
        guard let restartSeconds = pendingSubtitlePositionRestartSeconds else {
            return
        }

        pendingSubtitlePositionRestartSeconds = nil
        seek(to: restartSeconds)

        if !shouldResumeAfterSubtitlePositionRestart {
            mediaPlayer.pause()
        }
    }

    private func applyPendingResumeIfPossible() {
        guard
            let pendingResumeSeconds,
            durationSeconds > 0
        else {
            return
        }

        self.pendingResumeSeconds = nil

        guard pendingResumeSeconds >= 10 else {
            return
        }

        let lastUsefulPosition = max(durationSeconds - 30, 0)

        guard pendingResumeSeconds < lastUsefulPosition else {
            if let currentResumeIdentifier {
                resumeStore.remove(for: currentResumeIdentifier)
            }
            return
        }

        seek(to: pendingResumeSeconds)
    }

    private func saveResumeProgressIfNeeded() {
        guard durationSeconds > 0 else { return }

        let currentWholeSecond = Int(currentSeconds.rounded(.down))

        guard currentWholeSecond >= 10 else { return }
        guard abs(currentWholeSecond - lastSavedResumeSecond) >= 5 else { return }

        persistPlaybackProgress()
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }

        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%02d:%02d", minutes, secs)
    }

    private func queueSubtitle(url: URL, isAutomatic: Bool) {
        releaseSubtitleScope()

        subtitleURL = url
        isUsingSubtitleScope = url.startAccessingSecurityScopedResource()
        subtitleNeedsAttach = true
        pendingSubtitleIsAutomatic = isAutomatic
    }

    private func attachPendingSubtitleIfPossible() {
        guard subtitleNeedsAttach, let subtitleURL else { return }

        switch mediaPlayer.state {
        case .playing, .paused:
            break
        default:
            return
        }

        let result = mediaPlayer.addPlaybackSlave(
            subtitleURL,
            type: .subtitle,
            enforce: true
        )

        subtitleNeedsAttach = false

        if result == 0 {
            subtitleName = subtitleURL.lastPathComponent
            subtitleWasAutoLoaded = pendingSubtitleIsAutomatic
            mediaPlayer.currentVideoSubTitleDelay = subtitleDelayMilliseconds * 1_000
            mediaPlayer.currentSubTitleFontScale = subtitleFontScale
        } else {
            let wasAutomatic = pendingSubtitleIsAutomatic
            releaseSubtitleScope()

            if !wasAutomatic {
                errorMessage = "이 SRT 자막 파일을 연결할 수 없습니다."
            }
        }
    }

    private func findAutomaticSubtitle(for videoURL: URL) -> URL? {
        let videoStem = videoURL.deletingPathExtension().lastPathComponent
        let directoryURL = videoURL.deletingLastPathComponent()

        let directCandidate = directoryURL
            .appendingPathComponent(videoStem)
            .appendingPathExtension("srt")

        if FileManager.default.fileExists(atPath: directCandidate.path) {
            return directCandidate
        }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return files.first { candidate in
            candidate.pathExtension.caseInsensitiveCompare("srt") == .orderedSame &&
            candidate.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(videoStem) == .orderedSame
        }
    }

    private func releaseSubtitleScope() {
        if isUsingSubtitleScope {
            subtitleURL?.stopAccessingSecurityScopedResource()
        }

        subtitleURL = nil
        isUsingSubtitleScope = false
        subtitleNeedsAttach = false
        pendingSubtitleIsAutomatic = false
    }

    private func releaseSecurityScope() {
        if isUsingSecurityScope {
            securityScopedURL?.stopAccessingSecurityScopedResource()
        }

        securityScopedURL = nil
        isUsingSecurityScope = false
    }

    private func refreshTime() {
        currentSeconds = max(Double(mediaPlayer.time.intValue) / 1000.0, 0)
    }

    private func refreshDuration() {
        guard let media = mediaPlayer.media else { return }

        let seconds = Double(media.length.intValue) / 1000.0
        if seconds.isFinite, seconds > 0 {
            durationSeconds = seconds
        }
    }
}

extension PlayerViewModel: @preconcurrency VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        switch newState {
        case .opening, .buffering:
            isLoading = true

        case .playing:
            isLoading = false
            isPlaying = true
            refreshDuration()
            applyPendingResumeIfPossible()
            applyPendingSubtitlePositionRestartIfPossible()
            applyVideoDisplayMode()
            mediaPlayer.currentSubTitleFontScale = subtitleFontScale
            attachPendingSubtitleIfPossible()

        case .paused:
            isLoading = false
            isPlaying = false
            persistPlaybackProgress()
            attachPendingSubtitleIfPossible()

        case .stopping, .stopped:
            isLoading = false
            isPlaying = false

        case .error:
            isLoading = false
            isPlaying = false
            errorMessage = "이 파일의 일부 또는 전체를 정상적으로 읽을 수 없습니다."

        @unknown default:
            break
        }

        invalidatePictureInPicturePlaybackState()
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        refreshTime()
        refreshDuration()
        applyPendingResumeIfPossible()
        saveResumeProgressIfNeeded()
    }

    func mediaPlayerLengthChanged(_ length: Int64) {
        if length > 0 {
            durationSeconds = Double(length) / 1000.0
        }

        invalidatePictureInPicturePlaybackState()
    }
}
