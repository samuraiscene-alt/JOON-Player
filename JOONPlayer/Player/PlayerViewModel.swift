import Foundation
import MobileVLCKit
import UIKit

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

    let mediaPlayer = VLCMediaPlayer()

    private var securityScopedURL: URL?
    private var isUsingSecurityScope = false
    private var lastNonZeroVolume: Double = 1.0

    override init() {
        super.init()
        mediaPlayer.delegate = self
    }

    deinit {
        mediaPlayer.stop()
        releaseSecurityScope()
    }

    func attach(to view: UIView) {
        if mediaPlayer.drawable as? UIView !== view {
            mediaPlayer.drawable = view
        }
    }

    func load(url: URL) {
        mediaPlayer.stop()
        releaseSecurityScope()

        securityScopedURL = url
        isUsingSecurityScope = url.startAccessingSecurityScopedResource()

        hasMedia = true
        isLoading = true
        isPlaying = false
        currentSeconds = 0
        durationSeconds = 0
        errorMessage = nil
        fileName = url.lastPathComponent

        let media = VLCMedia(url: url)
        mediaPlayer.media = media
        mediaPlayer.rate = playbackRate

        applyVolumeToEngine()
        mediaPlayer.play()
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

    func present(error: String) {
        errorMessage = error
    }

    var formattedCurrentTime: String {
        Self.formatTime(currentSeconds)
    }

    var formattedDuration: String {
        Self.formatTime(durationSeconds)
    }

    private func applyVolumeToEngine() {
        let effectiveVolume = isMuted ? 0 : volume
        mediaPlayer.audio.isMuted = isMuted
        mediaPlayer.audio.volume = Int32((effectiveVolume * 100).rounded())
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

extension PlayerViewModel: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            switch mediaPlayer.state {
            case .opening, .buffering:
                isLoading = true

            case .playing:
                isLoading = false
                isPlaying = true
                refreshDuration()

            case .paused:
                isLoading = false
                isPlaying = false

            case .stopped:
                isLoading = false
                isPlaying = false

            case .ended:
                isLoading = false
                isPlaying = false
                refreshTime()

            case .error:
                isLoading = false
                isPlaying = false
                errorMessage = "이 파일의 일부 또는 전체를 정상적으로 읽을 수 없습니다."

            default:
                break
            }
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            refreshTime()
            refreshDuration()
        }
    }
}
