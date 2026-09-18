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

struct MediaTrackOption: Identifiable, Equatable {
    let id: String
    let name: String
    let isSelected: Bool
}

struct MediaInfoField: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String

    init(
        _ label: String,
        _ value: String
    ) {
        id = label
        self.label = label
        self.value = value
    }
}

struct MediaInfoTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let isSelected: Bool
    let fields: [MediaInfoField]
}

struct MediaInfoSnapshot: Equatable {
    let fileFields: [MediaInfoField]
    let videoTracks: [MediaInfoTrack]
    let audioTracks: [MediaInfoTrack]
    let textTracks: [MediaInfoTrack]
}

enum VideoSnapshotError: LocalizedError {
    case noVideoOutput
    case timedOut

    var errorDescription: String? {
        switch self {
        case .noVideoOutput:
            return "현재 장면을 캡처할 수 있는 영상 출력이 아직 준비되지 않았습니다."
        case .timedOut:
            return "스크린샷 파일을 만드는 데 시간이 너무 오래 걸렸습니다. 잠시 뒤 다시 시도해 주세요."
        }
    }
}

struct MediaChapterOption: Identifiable, Equatable {
    let id: Int
    let name: String
    let startSeconds: Double
    let durationSeconds: Double
    let isCurrent: Bool

    var startTimeText: String {
        let total = max(Int(startSeconds.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }
}

struct PlaybackBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let seconds: Double
    let createdAt: Date

    var timeText: String {
        let total = max(Int(seconds.rounded(.down)), 0)
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
}

struct PlaybackQueueItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let fileName: String

    init(url: URL) {
        id = UUID()
        self.url = url
        fileName = url.lastPathComponent
    }
}

enum PlaylistRepeatMode: String, CaseIterable, Identifiable {
    case off
    case all
    case one

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "반복 끔"
        case .all:
            return "전체 반복"
        case .one:
            return "한 곡 반복"
        }
    }

    var systemImage: String {
        switch self {
        case .off, .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }
}

enum SleepTimerMode: String, CaseIterable, Identifiable {
    case off
    case minutes15
    case minutes30
    case minutes60
    case endOfCurrentVideo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "끔"
        case .minutes15:
            return "15분"
        case .minutes30:
            return "30분"
        case .minutes60:
            return "60분"
        case .endOfCurrentVideo:
            return "영상 끝"
        }
    }

    var durationSeconds: TimeInterval? {
        switch self {
        case .minutes15:
            return 15 * 60
        case .minutes30:
            return 30 * 60
        case .minutes60:
            return 60 * 60
        case .off, .endOfCurrentVideo:
            return nil
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

    @Published private(set) var abRepeatStartSeconds: Double?
    @Published private(set) var abRepeatEndSeconds: Double?

    @Published private(set) var sleepTimerMode: SleepTimerMode = .off
    @Published private(set) var sleepTimerRemainingSeconds: Int?

    @Published private(set) var audioTrackOptions: [MediaTrackOption] = []
    @Published private(set) var textTrackOptions: [MediaTrackOption] = []
    @Published private(set) var chapterOptions: [MediaChapterOption] = []
    @Published private(set) var playbackBookmarks: [PlaybackBookmark] = []

    @Published var subtitleName: String?
    @Published var subtitleWasAutoLoaded = false
    @Published var subtitleDelayMilliseconds = 0
    @Published var subtitleFontScale: Float = 1.0
    @Published var subtitleVerticalPosition: SubtitleVerticalPosition = .standard

    @Published var isPictureInPictureReady = false
    @Published var isPictureInPictureActive = false

    @Published private(set) var playlistItems: [PlaybackQueueItem] = []
    @Published private(set) var playlistIndex: Int = 0
    @Published private(set) var playlistRepeatMode: PlaylistRepeatMode = .off
    @Published private(set) var isPlaylistShuffleEnabled = false

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

    private var suppressAutomaticAdvance = true
    private var lastObservedPlaybackSecond: Double = 0
    private var playlistBaseItems: [PlaybackQueueItem] = []

    private var sleepTimerTask: Task<Void, Never>?
    private var sleepTimerDeadline: Date?

    private enum PreferenceKey {
        static let subtitleFontScale = "joonplayer.subtitle.fontScale"
        static let subtitleVerticalPosition = "joonplayer.subtitle.verticalPosition"
        static let playbackBookmarks = "joonplayer.playback.bookmarks.v1"
    }

    private enum BookmarkRule {
        static let duplicateThreshold: Double = 0.75
        static let maximumPerMedia = 50
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
        sleepTimerTask?.cancel()
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
        let item = PlaybackQueueItem(url: url)

        playlistBaseItems = [item]
        playlistItems = [item]
        playlistIndex = 0
        playlistRepeatMode = .off
        isPlaylistShuffleEnabled = false

        loadMedia(url: url)
    }

    func loadPlaylist(urls: [URL]) {
        var seenPaths = Set<String>()
        let uniqueURLs = urls.filter { url in
            let path = url.standardizedFileURL.path.lowercased()
            return seenPaths.insert(path).inserted
        }

        guard let firstURL = uniqueURLs.first else { return }

        playlistBaseItems = uniqueURLs.map(PlaybackQueueItem.init(url:))
        playlistItems = playlistBaseItems
        playlistIndex = 0
        playlistRepeatMode = .off
        isPlaylistShuffleEnabled = false

        loadMedia(url: firstURL)
    }

    func playNextPlaylistItem() {
        guard playlistItems.count > 1 else { return }

        if playlistIndex + 1 < playlistItems.count {
            playlistIndex += 1
        } else if playlistRepeatMode == .all {
            playlistIndex = 0
        } else {
            return
        }

        loadMedia(url: playlistItems[playlistIndex].url)
    }

    func playPreviousPlaylistItem() {
        guard playlistItems.count > 1 else { return }

        if playlistIndex > 0 {
            playlistIndex -= 1
        } else if playlistRepeatMode == .all {
            playlistIndex = playlistItems.count - 1
        } else {
            return
        }

        loadMedia(url: playlistItems[playlistIndex].url)
    }

    func playPlaylistItem(id: UUID) {
        guard let index = playlistItems.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        guard index != playlistIndex else { return }

        playlistIndex = index
        loadMedia(url: playlistItems[index].url)
    }

    func cyclePlaylistRepeatMode() {
        switch playlistRepeatMode {
        case .off:
            playlistRepeatMode = .all
        case .all:
            playlistRepeatMode = .one
        case .one:
            playlistRepeatMode = .off
        }
    }

    func togglePlaylistShuffle() {
        guard playlistItems.count > 1 else { return }
        guard let currentID = currentPlaylistItemID else { return }

        if isPlaylistShuffleEnabled {
            playlistItems = playlistBaseItems
            playlistIndex = playlistItems.firstIndex {
                $0.id == currentID
            } ?? 0
            isPlaylistShuffleEnabled = false
            return
        }

        let currentIndex = playlistIndex
        let currentItem = playlistItems[currentIndex]

        var shuffledItems = playlistBaseItems.filter {
            $0.id != currentID
        }
        shuffledItems.shuffle()

        let insertionIndex = min(
            currentIndex,
            shuffledItems.count
        )

        shuffledItems.insert(
            currentItem,
            at: insertionIndex
        )

        playlistItems = shuffledItems
        playlistIndex = insertionIndex
        isPlaylistShuffleEnabled = true
    }

    func movePlaylistItemUp(id: UUID) {
        guard !isPlaylistShuffleEnabled else { return }
        guard let index = playlistItems.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        guard index > 0 else { return }
        movePlaylistItem(from: index, to: index - 1)
    }

    func movePlaylistItemDown(id: UUID) {
        guard !isPlaylistShuffleEnabled else { return }
        guard let index = playlistItems.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        guard index + 1 < playlistItems.count else { return }
        movePlaylistItem(from: index, to: index + 1)
    }

    func canMovePlaylistItemUp(id: UUID) -> Bool {
        guard !isPlaylistShuffleEnabled else { return false }

        return playlistItems.firstIndex {
            $0.id == id
        }.map { $0 > 0 } ?? false
    }

    func canMovePlaylistItemDown(id: UUID) -> Bool {
        guard !isPlaylistShuffleEnabled else { return false }

        return playlistItems.firstIndex {
            $0.id == id
        }.map { $0 + 1 < playlistItems.count } ?? false
    }

    private func movePlaylistItem(
        from sourceIndex: Int,
        to destinationIndex: Int
    ) {
        guard playlistItems.indices.contains(sourceIndex) else { return }
        guard playlistItems.indices.contains(destinationIndex) else { return }
        guard let currentID = currentPlaylistItemID else { return }

        let item = playlistItems.remove(at: sourceIndex)
        playlistItems.insert(item, at: destinationIndex)

        playlistBaseItems = playlistItems
        playlistIndex = playlistItems.firstIndex {
            $0.id == currentID
        } ?? 0
    }

    private func loadMedia(
        url: URL,
        allowResume: Bool = true
    ) {
        persistPlaybackProgress()

        suppressAutomaticAdvance = true
        mediaPlayer.stop()

        releaseSubtitleScope()
        releaseSecurityScope()

        securityScopedURL = url
        isUsingSecurityScope = url.startAccessingSecurityScopedResource()

        currentResumeIdentifier = PlaybackResumeStore.identifier(for: url)
        loadPlaybackBookmarks()

        pendingResumeSeconds = allowResume
            ? currentResumeIdentifier.flatMap {
                resumeStore.position(for: $0)
            }
            : nil
        lastSavedResumeSecond = -1
        lastObservedPlaybackSecond = 0

        hasMedia = true
        isLoading = true
        isPlaying = false
        currentSeconds = 0
        durationSeconds = 0
        errorMessage = nil
        fileName = url.lastPathComponent

        clearABRepeat()

        audioTrackOptions = []
        textTrackOptions = []
        chapterOptions = []

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
        playbackBookmarks = []

        pictureInPictureController = nil
        isPictureInPictureReady = false
        isPictureInPictureActive = false

        suppressAutomaticAdvance = true
        lastObservedPlaybackSecond = 0
        playlistBaseItems = []
        playlistItems = []
        playlistIndex = 0
        playlistRepeatMode = .off
        isPlaylistShuffleEnabled = false

        hasMedia = false
        isPlaying = false
        isLoading = false
        currentSeconds = 0
        durationSeconds = 0
        fileName = ""

        clearABRepeat()
        clearSleepTimer()

        audioTrackOptions = []
        textTrackOptions = []
        chapterOptions = []

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

    func stepToPreviousFrame() {
        guard canStepFrames else {
            errorMessage = "프레임 이동은 영상 출력이 준비된 재생/일시정지 상태에서 사용할 수 있습니다."
            return
        }

        mediaPlayer.gotoPreviousFrame()
    }

    func stepToNextFrame() {
        guard canStepFrames else {
            errorMessage = "프레임 이동은 영상 출력이 준비된 재생/일시정지 상태에서 사용할 수 있습니다."
            return
        }

        mediaPlayer.gotoNextFrame()
    }

    func addPlaybackBookmark() {
        guard
            hasMedia,
            durationSeconds > 0,
            currentResumeIdentifier != nil
        else {
            errorMessage = "북마크를 저장할 수 있는 영상이 준비되지 않았습니다."
            return
        }

        let target = min(
            max(currentSeconds, 0),
            durationSeconds
        )

        guard playbackBookmarks.contains(
            where: {
                abs($0.seconds - target)
                    <= BookmarkRule.duplicateThreshold
            }
        ) == false else {
            return
        }

        playbackBookmarks.append(
            PlaybackBookmark(
                id: UUID(),
                seconds: target,
                createdAt: Date()
            )
        )

        if playbackBookmarks.count
            > BookmarkRule.maximumPerMedia
        {
            let oldestIDs = playbackBookmarks
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(
                    playbackBookmarks.count
                    - BookmarkRule.maximumPerMedia
                )
                .map(\.id)

            playbackBookmarks.removeAll {
                oldestIDs.contains($0.id)
            }
        }

        playbackBookmarks.sort {
            $0.seconds < $1.seconds
        }

        savePlaybackBookmarks()
    }

    func jumpToPlaybackBookmark(
        id: UUID
    ) {
        guard let bookmark = playbackBookmarks.first(
            where: { $0.id == id }
        ) else {
            return
        }

        seek(to: bookmark.seconds)
    }

    func removePlaybackBookmark(
        id: UUID
    ) {
        playbackBookmarks.removeAll {
            $0.id == id
        }
        savePlaybackBookmarks()
    }

    func removeAllPlaybackBookmarks() {
        guard !playbackBookmarks.isEmpty else { return }

        playbackBookmarks = []
        savePlaybackBookmarks()
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

    func markABRepeatStart() {
        guard hasMedia, durationSeconds > 0 else { return }

        let latestStart = max(durationSeconds - 0.5, 0)
        abRepeatStartSeconds = min(
            max(currentSeconds, 0),
            latestStart
        )
        abRepeatEndSeconds = nil
    }

    func markABRepeatEnd() {
        guard
            let startSeconds = abRepeatStartSeconds,
            durationSeconds > 0
        else {
            return
        }

        let minimumEnd = startSeconds + 0.5
        guard currentSeconds >= minimumEnd else { return }

        abRepeatEndSeconds = min(
            currentSeconds,
            durationSeconds
        )
    }

    func clearABRepeat() {
        abRepeatStartSeconds = nil
        abRepeatEndSeconds = nil
    }

    func setSleepTimer(_ mode: SleepTimerMode) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerDeadline = nil
        sleepTimerRemainingSeconds = nil
        sleepTimerMode = mode

        guard let durationSeconds = mode.durationSeconds else {
            return
        }

        let deadline = Date().addingTimeInterval(durationSeconds)
        sleepTimerDeadline = deadline
        sleepTimerRemainingSeconds = Int(durationSeconds.rounded(.up))

        sleepTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.refreshSleepTimer()
            }
        }
    }

    func clearSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerDeadline = nil
        sleepTimerRemainingSeconds = nil
        sleepTimerMode = .off
    }

    func setVideoDisplayMode(_ mode: VideoDisplayMode) {
        videoDisplayMode = mode
        applyVideoDisplayMode()
    }

    func captureCurrentFrameSnapshot() async throws -> URL {
        guard
            hasMedia,
            !isLoading,
            !mediaPlayer.videoTracks.isEmpty,
            mediaPlayer.state == .playing
                || mediaPlayer.state == .paused
        else {
            throw VideoSnapshotError.noVideoOutput
        }

        let baseName = securityScopedURL?
            .deletingPathExtension()
            .lastPathComponent
            ?? "JOON_Player"

        let timeLabel = Self.snapshotTimeLabel(
            currentSeconds
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(baseName)_snapshot_\(timeLabel)_\(UUID().uuidString.prefix(6))"
            )
            .appendingPathExtension("png")

        try? FileManager.default.removeItem(at: outputURL)

        mediaPlayer.saveVideoSnapshot(
            at: outputURL.path,
            withWidth: 0,
            andHeight: 0
        )

        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(50))

            if
                FileManager.default.fileExists(
                    atPath: outputURL.path
                ),
                let attributes = try? FileManager.default
                    .attributesOfItem(
                        atPath: outputURL.path
                    ),
                let fileSize = attributes[.size] as? NSNumber,
                fileSize.int64Value > 0
            {
                return outputURL
            }
        }

        try? FileManager.default.removeItem(at: outputURL)
        throw VideoSnapshotError.timedOut
    }

    func mediaInfoSnapshot() -> MediaInfoSnapshot {
        let url = securityScopedURL

        let fileSize = try? url?.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize

        let fileFields: [MediaInfoField] = [
            MediaInfoField(
                "파일명",
                fileName.isEmpty ? "알 수 없음" : fileName
            ),
            MediaInfoField(
                "형식",
                url?.pathExtension.uppercased().isEmpty == false
                    ? url!.pathExtension.uppercased()
                    : "알 수 없음"
            ),
            MediaInfoField(
                "파일 크기",
                fileSize.flatMap { $0 }.map {
                    ByteCountFormatter.string(
                        fromByteCount: Int64($0),
                        countStyle: .file
                    )
                } ?? "알 수 없음"
            ),
            MediaInfoField(
                "재생 시간",
                durationSeconds > 0
                    ? Self.formatTime(durationSeconds)
                    : "알 수 없음"
            )
        ]

        let videoInfo = mediaPlayer.videoTracks.enumerated().map {
            index,
            track in

            let video = track.video
            let width = Int(video?.width ?? 0)
            let height = Int(video?.height ?? 0)
            let frameRate = Int(video?.frameRate ?? 0)
            let frameRateDenominator = max(
                Int(video?.frameRateDenominator ?? 0),
                1
            )

            var fields = [
                MediaInfoField(
                    "코덱",
                    mediaInfoCodecName(track)
                )
            ]

            if width > 0, height > 0 {
                fields.append(
                    MediaInfoField(
                        "해상도",
                        "\(width) × \(height)"
                    )
                )
            }

            if frameRate > 0 {
                let fps =
                    Double(frameRate)
                    / Double(frameRateDenominator)

                fields.append(
                    MediaInfoField(
                        "FPS",
                        fps.formatted(
                            .number.precision(
                                .fractionLength(0...3)
                            )
                        )
                    )
                )
            }

            if track.bitrate > 0 {
                fields.append(
                    MediaInfoField(
                        "비트레이트",
                        formatMediaBitrate(track.bitrate)
                    )
                )
            }

            if let language = normalizedOptionalText(
                track.language
            ) {
                fields.append(
                    MediaInfoField("언어", language)
                )
            }

            return MediaInfoTrack(
                id: track.trackId,
                title: normalizedTrackName(
                    track.trackName,
                    fallback: "비디오 \(index + 1)"
                ),
                isSelected: track.isSelected,
                fields: fields
            )
        }

        let audioInfo = mediaPlayer.audioTracks.enumerated().map {
            index,
            track in

            let audio = track.audio
            let channels = Int(audio?.channelsNumber ?? 0)
            let sampleRate = Int(audio?.rate ?? 0)

            var fields = [
                MediaInfoField(
                    "코덱",
                    mediaInfoCodecName(track)
                )
            ]

            if channels > 0 {
                fields.append(
                    MediaInfoField(
                        "채널",
                        formatAudioChannels(channels)
                    )
                )
            }

            if sampleRate > 0 {
                fields.append(
                    MediaInfoField(
                        "샘플레이트",
                        "\(sampleRate.formatted()) Hz"
                    )
                )
            }

            if track.bitrate > 0 {
                fields.append(
                    MediaInfoField(
                        "비트레이트",
                        formatMediaBitrate(track.bitrate)
                    )
                )
            }

            if let language = normalizedOptionalText(
                track.language
            ) {
                fields.append(
                    MediaInfoField("언어", language)
                )
            }

            return MediaInfoTrack(
                id: track.trackId,
                title: normalizedTrackName(
                    track.trackName,
                    fallback: "오디오 \(index + 1)"
                ),
                isSelected: track.isSelected,
                fields: fields
            )
        }

        let textInfo = mediaPlayer.textTracks.enumerated().map {
            index,
            track in

            var fields = [
                MediaInfoField(
                    "코덱",
                    mediaInfoCodecName(track)
                )
            ]

            if let encoding = normalizedOptionalText(
                track.text?.encoding
            ) {
                fields.append(
                    MediaInfoField("인코딩", encoding)
                )
            }

            if let language = normalizedOptionalText(
                track.language
            ) {
                fields.append(
                    MediaInfoField("언어", language)
                )
            }

            return MediaInfoTrack(
                id: track.trackId,
                title: normalizedTrackName(
                    track.trackName,
                    fallback: "자막 \(index + 1)"
                ),
                isSelected: track.isSelected,
                fields: fields
            )
        }

        return MediaInfoSnapshot(
            fileFields: fileFields,
            videoTracks: videoInfo,
            audioTracks: audioInfo,
            textTracks: textInfo
        )
    }

    func refreshAvailableTracks() {
        audioTrackOptions = mediaPlayer.audioTracks.enumerated().map {
            index,
            track in

            MediaTrackOption(
                id: track.trackId,
                name: normalizedTrackName(
                    track.trackName,
                    fallback: "오디오 \(index + 1)"
                ),
                isSelected: track.isSelected
            )
        }

        textTrackOptions = mediaPlayer.textTracks.enumerated().map {
            index,
            track in

            MediaTrackOption(
                id: track.trackId,
                name: normalizedTrackName(
                    track.trackName,
                    fallback: "자막 \(index + 1)"
                ),
                isSelected: track.isSelected
            )
        }
    }

    func selectAudioTrack(id: String) {
        guard let track = mediaPlayer.audioTracks.first(
            where: { $0.trackId == id }
        ) else {
            refreshAvailableTracks()
            return
        }

        track.isSelectedExclusively = true
        refreshAvailableTracks()
    }

    func selectTextTrack(id: String?) {
        guard let id else {
            mediaPlayer.deselectAllTextTracks()
            refreshAvailableTracks()
            return
        }

        guard let track = mediaPlayer.textTracks.first(
            where: { $0.trackId == id }
        ) else {
            refreshAvailableTracks()
            return
        }

        track.isSelectedExclusively = true
        refreshAvailableTracks()
    }

    func refreshAvailableChapters() {
        let titleIndex = mediaPlayer.currentTitleIndex >= 0
            ? mediaPlayer.currentTitleIndex
            : 0

        let descriptions = mediaPlayer.chapterDescriptions(
            ofTitle: titleIndex
        )

        chapterOptions = descriptions.enumerated().map {
            position,
            chapter in

            let startMilliseconds =
                chapter.timeOffset.value?.doubleValue
                ?? Double(chapter.timeOffset.intValue)

            let durationMilliseconds =
                chapter.durationTime.value?.doubleValue
                ?? Double(chapter.durationTime.intValue)

            let trimmedName = chapter.name?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                ?? ""

            return MediaChapterOption(
                id: Int(chapter.chapterIndex),
                name: trimmedName.isEmpty
                    ? "챕터 \(position + 1)"
                    : trimmedName,
                startSeconds: max(startMilliseconds / 1000.0, 0),
                durationSeconds: max(
                    durationMilliseconds / 1000.0,
                    0
                ),
                isCurrent: chapter.isCurrent
                    || Int(chapter.chapterIndex)
                        == Int(mediaPlayer.currentChapterIndex)
            )
        }
    }

    func selectChapter(index: Int) {
        guard chapterOptions.contains(
            where: { $0.id == index }
        ) else {
            refreshAvailableChapters()
            return
        }

        mediaPlayer.currentChapterIndex = Int32(index)
        refreshAvailableChapters()
    }

    func playPreviousChapter() {
        guard canPlayPreviousChapter else { return }

        mediaPlayer.previousChapter()
        refreshAvailableChapters()
    }

    func playNextChapter() {
        guard canPlayNextChapter else { return }

        mediaPlayer.nextChapter()
        refreshAvailableChapters()
    }

    func loadSubtitle(url: URL) {
        guard hasMedia else {
            errorMessage = "동영상을 먼저 연 뒤 자막을 선택해 주세요."
            return
        }

        queueSubtitle(url: url, isAutomatic: false)
        attachPendingSubtitleIfPossible()
        refreshAvailableTracks()
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

    var canStepFrames: Bool {
        guard
            hasMedia,
            !isLoading,
            !mediaPlayer.videoTracks.isEmpty
        else {
            return false
        }

        return mediaPlayer.state == .playing
            || mediaPlayer.state == .paused
    }

    var canAddPlaybackBookmark: Bool {
        guard
            hasMedia,
            durationSeconds > 0,
            currentResumeIdentifier != nil
        else {
            return false
        }

        return playbackBookmarks.contains {
            abs($0.seconds - currentSeconds)
                <= BookmarkRule.duplicateThreshold
        } == false
    }

    func isCurrentPlaybackBookmark(
        _ bookmark: PlaybackBookmark
    ) -> Bool {
        abs(bookmark.seconds - currentSeconds) <= 0.75
    }

    var selectedAudioTrackName: String {
        audioTrackOptions.first(where: { $0.isSelected })?.name
            ?? "자동"
    }

    var selectedTextTrackName: String {
        textTrackOptions.first(where: { $0.isSelected })?.name
            ?? "끔"
    }

    var currentChapterName: String {
        chapterOptions.first(where: { $0.isCurrent })?.name
            ?? chapterOptions.first(
                where: {
                    $0.id == Int(mediaPlayer.currentChapterIndex)
                }
            )?.name
            ?? "챕터"
    }

    var canPlayPreviousChapter: Bool {
        guard chapterOptions.count > 1 else { return false }

        return Int(mediaPlayer.currentChapterIndex) > 0
    }

    var canPlayNextChapter: Bool {
        guard chapterOptions.count > 1 else { return false }

        let currentIndex = Int(mediaPlayer.currentChapterIndex)
        return currentIndex >= 0
            && currentIndex < chapterOptions.count - 1
    }

    var playlistCount: Int {
        playlistItems.count
    }

    var currentPlaylistItemID: UUID? {
        guard playlistItems.indices.contains(playlistIndex) else {
            return nil
        }

        return playlistItems[playlistIndex].id
    }

    var playlistPositionText: String {
        guard playlistCount > 0 else { return "" }
        return "\(playlistIndex + 1) / \(playlistCount)"
    }

    var canPlayPreviousPlaylistItem: Bool {
        guard playlistItems.count > 1 else { return false }

        return playlistIndex > 0
            || playlistRepeatMode == .all
    }

    var canPlayNextPlaylistItem: Bool {
        guard playlistItems.count > 1 else { return false }

        return playlistIndex + 1 < playlistItems.count
            || playlistRepeatMode == .all
    }

    var isABRepeatActive: Bool {
        guard
            let startSeconds = abRepeatStartSeconds,
            let endSeconds = abRepeatEndSeconds
        else {
            return false
        }

        return endSeconds > startSeconds
    }

    var canSetABRepeatEnd: Bool {
        guard let startSeconds = abRepeatStartSeconds else {
            return false
        }

        return currentSeconds >= startSeconds + 0.5
    }

    var formattedABRepeatStart: String {
        guard let abRepeatStartSeconds else { return "--:--" }
        return Self.formatTime(abRepeatStartSeconds)
    }

    var formattedABRepeatEnd: String {
        guard let abRepeatEndSeconds else { return "--:--" }
        return Self.formatTime(abRepeatEndSeconds)
    }

    var sleepTimerStatusText: String {
        switch sleepTimerMode {
        case .off:
            return "꺼짐"

        case .endOfCurrentVideo:
            return "현재 영상 끝나면 정지"

        case .minutes15, .minutes30, .minutes60:
            guard let sleepTimerRemainingSeconds else {
                return sleepTimerMode.title
            }

            let minutes = sleepTimerRemainingSeconds / 60
            let seconds = sleepTimerRemainingSeconds % 60

            return String(
                format: "%02d:%02d 후 정지",
                minutes,
                seconds
            )
        }
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

    private func loadPlaybackBookmarks() {
        guard let identifier = currentResumeIdentifier else {
            playbackBookmarks = []
            return
        }

        let allBookmarks = readPlaybackBookmarkStorage()
        playbackBookmarks = allBookmarks[identifier, default: []]
            .sorted { $0.seconds < $1.seconds }
    }

    private func savePlaybackBookmarks() {
        guard let identifier = currentResumeIdentifier else {
            return
        }

        var allBookmarks = readPlaybackBookmarkStorage()

        if playbackBookmarks.isEmpty {
            allBookmarks.removeValue(forKey: identifier)
        } else {
            allBookmarks[identifier] = playbackBookmarks
        }

        if allBookmarks.isEmpty {
            UserDefaults.standard.removeObject(
                forKey: PreferenceKey.playbackBookmarks
            )
            return
        }

        guard let data = try? JSONEncoder().encode(
            allBookmarks
        ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: PreferenceKey.playbackBookmarks
        )
    }

    private func readPlaybackBookmarkStorage()
        -> [String: [PlaybackBookmark]]
    {
        guard
            let data = UserDefaults.standard.data(
                forKey: PreferenceKey.playbackBookmarks
            ),
            let decoded = try? JSONDecoder().decode(
                [String: [PlaybackBookmark]].self,
                from: data
            )
        else {
            return [:]
        }

        return decoded
    }

    private func normalizedTrackName(
        _ name: String,
        fallback: String
    ) -> String {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalizedOptionalText(
        _ value: String?
    ) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }

    private func mediaInfoCodecName(
        _ track: VLCMediaPlayer.Track
    ) -> String {
        let name = track.codecName().trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return name.isEmpty ? "알 수 없음" : name
    }

    private func formatMediaBitrate(
        _ bitrate: UInt32
    ) -> String {
        let value = Double(bitrate)

        if value >= 1_000_000 {
            return String(
                format: "%.2f Mbps",
                value / 1_000_000
            )
        }

        if value >= 1_000 {
            return String(
                format: "%.0f kbps",
                value / 1_000
            )
        }

        return "\(bitrate) bps"
    }

    private func formatAudioChannels(
        _ channels: Int
    ) -> String {
        switch channels {
        case 1:
            return "1채널 · 모노"
        case 2:
            return "2채널 · 스테레오"
        default:
            return "\(channels)채널"
        }
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

    private func refreshCurrentChapterSelectionIfNeeded() {
        guard !chapterOptions.isEmpty else { return }

        let currentIndex = Int(mediaPlayer.currentChapterIndex)

        guard chapterOptions.contains(
            where: {
                $0.id == currentIndex
                    && $0.isCurrent
            }
        ) == false else {
            return
        }

        chapterOptions = chapterOptions.map { chapter in
            MediaChapterOption(
                id: chapter.id,
                name: chapter.name,
                startSeconds: chapter.startSeconds,
                durationSeconds: chapter.durationSeconds,
                isCurrent: chapter.id == currentIndex
            )
        }
    }

    private func refreshSleepTimer() {
        guard
            sleepTimerMode != .off,
            sleepTimerMode != .endOfCurrentVideo,
            let sleepTimerDeadline
        else {
            return
        }

        let remaining = Int(
            ceil(sleepTimerDeadline.timeIntervalSinceNow)
        )

        if remaining <= 0 {
            persistPlaybackProgress()

            if mediaPlayer.isPlaying {
                mediaPlayer.pause()
            }

            clearSleepTimer()
            return
        }

        sleepTimerRemainingSeconds = remaining
    }

    private func enforceABRepeatIfNeeded() {
        guard
            isABRepeatActive,
            let startSeconds = abRepeatStartSeconds,
            let endSeconds = abRepeatEndSeconds
        else {
            return
        }

        guard currentSeconds >= endSeconds - 0.05 else {
            return
        }

        seek(to: startSeconds)
    }

    private func saveResumeProgressIfNeeded() {
        guard durationSeconds > 0 else { return }

        let currentWholeSecond = Int(currentSeconds.rounded(.down))

        guard currentWholeSecond >= 10 else { return }
        guard abs(currentWholeSecond - lastSavedResumeSecond) >= 5 else { return }

        persistPlaybackProgress()
    }

    private static func snapshotTimeLabel(
        _ seconds: Double
    ) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00-00"
        }

        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(
                format: "%02d-%02d-%02d",
                hours,
                minutes,
                secs
            )
        }

        return String(
            format: "%02d-%02d",
            minutes,
            secs
        )
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
            suppressAutomaticAdvance = false
            refreshDuration()
            applyPendingResumeIfPossible()
            applyPendingSubtitlePositionRestartIfPossible()
            applyVideoDisplayMode()
            mediaPlayer.currentSubTitleFontScale = subtitleFontScale
            attachPendingSubtitleIfPossible()
            refreshAvailableTracks()
            refreshAvailableChapters()

        case .paused:
            isLoading = false
            isPlaying = false
            persistPlaybackProgress()
            attachPendingSubtitleIfPossible()
            refreshAvailableTracks()
            refreshAvailableChapters()

        case .stopping:
            isLoading = false
            isPlaying = false

        case .stopped:
            let finishedNaturally =
                !suppressAutomaticAdvance
                && hasMedia
                && durationSeconds > 0
                && lastObservedPlaybackSecond
                    >= max(durationSeconds - 1.5, 0)

            isLoading = false
            isPlaying = false

            if
                finishedNaturally,
                sleepTimerMode == .endOfCurrentVideo
            {
                persistPlaybackProgress()
                clearSleepTimer()
            } else if
                finishedNaturally,
                isABRepeatActive,
                let startSeconds = abRepeatStartSeconds
            {
                seek(to: startSeconds)
                mediaPlayer.play()
            } else if finishedNaturally {
                switch playlistRepeatMode {
                case .one:
                    if playlistItems.indices.contains(playlistIndex) {
                        loadMedia(
                            url: playlistItems[playlistIndex].url,
                            allowResume: false
                        )
                    }

                case .off, .all:
                    if canPlayNextPlaylistItem {
                        playNextPlaylistItem()
                    }
                }
            }

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
        lastObservedPlaybackSecond = currentSeconds
        applyPendingResumeIfPossible()
        refreshCurrentChapterSelectionIfNeeded()
        enforceABRepeatIfNeeded()
        saveResumeProgressIfNeeded()
    }

    func mediaPlayerLengthChanged(_ length: Int64) {
        if length > 0 {
            durationSeconds = Double(length) / 1000.0
        }

        invalidatePictureInPicturePlaybackState()
    }
}
