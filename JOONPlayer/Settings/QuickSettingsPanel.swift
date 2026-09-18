import SwiftUI

private enum QuickSettingsGroup {
    case playback
    case audio
    case subtitles
    case other
}

struct QuickSettingsPanel: View {
    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @ObservedObject var player: PlayerViewModel
    let onChooseAnotherVideo: () -> Void
    let onChooseSubtitle: () -> Void
    let onRepairVideo: () -> Void
    let onShowMediaInfo: () -> Void
    let onCaptureSnapshot: () -> Void

    @State private var expandedGroup: QuickSettingsGroup? = .playback

    private let rates: [Float] = [0.5, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("빠른 설정")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)

                settingsGroup(
                    .playback,
                    title: "재생",
                    systemImage: "play.rectangle",
                    summary: playbackGroupSummary
                ) {
                    playbackGroupContent
                }

                settingsGroup(
                    .audio,
                    title: "오디오",
                    systemImage: "speaker.wave.2",
                    summary: audioGroupSummary
                ) {
                    audioGroupContent
                }

                settingsGroup(
                    .subtitles,
                    title: "자막",
                    systemImage: "captions.bubble",
                    summary: subtitleGroupSummary
                ) {
                    subtitleGroupContent
                }

                settingsGroup(
                    .other,
                    title: "기타",
                    systemImage: "ellipsis.circle",
                    summary: nil
                ) {
                    otherGroupContent
                }
            }
            .padding(14)
        }
        .frame(maxWidth: 340, maxHeight: 520)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .onAppear {
            player.refreshAvailableTracks()
            player.refreshAvailableChapters()
        }
    }

    private var playbackGroupSummary: String {
        "\(rateLabel(player.playbackRate)) · "
        + player.videoDisplayMode.title
    }

    private var audioGroupSummary: String {
        player.selectedAudioTrackName
        + " · "
        + player.audioOutputMode.title
    }

    private var subtitleGroupSummary: String {
        if player.subtitleName != nil {
            return "외부 SRT"
        }

        return player.selectedTextTrackName
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(
        _ group: QuickSettingsGroup,
        title: String,
        systemImage: String,
        summary: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedGroup == group

        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedGroup = isExpanded
                        ? nil
                        : group
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 22)

                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    if
                        let summary,
                        !dynamicTypeSize.isAccessibilitySize
                    {
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Image(
                        systemName: isExpanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) 설정")
            .accessibilityValue(
                [
                    summary,
                    isExpanded ? "펼쳐짐" : "접힘"
                ]
                .compactMap { $0 }
                .joined(separator: ", ")
            )
            .accessibilityHint(
                isExpanded
                ? "두 번 탭하면 설정을 접습니다."
                : "두 번 탭하면 설정을 펼칩니다."
            )

            if isExpanded {
                Divider()
                    .overlay(.white.opacity(0.1))

                content()
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 13)
                    .transition(.opacity)
            }
        }
        .background(.white.opacity(0.055))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private var playbackGroupContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            playbackRateSection
            groupDivider
            frameStepSection
            groupDivider
            bookmarkSection
            groupDivider
            abRepeatSection
            groupDivider
            sleepTimerSection
            groupDivider
            chapterSection
            groupDivider
            videoDisplaySection
        }
    }

    private var audioGroupContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            audioTrackSection
            groupDivider
            audioSyncSection
            groupDivider
            audioOutputSection
            groupDivider
            equalizerSection
        }
    }

    private var subtitleGroupContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            textTrackSection
            groupDivider
            subtitleSection
        }
    }

    private var otherGroupContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            pictureInPictureRow
            groupDivider
            repairRow
            groupDivider
            mediaInfoRow
            groupDivider
            snapshotRow
            groupDivider
            chooseVideoRow
        }
    }

    private var groupDivider: some View {
        Divider()
            .overlay(.white.opacity(0.1))
            .accessibilityHidden(true)
    }

    private var choiceLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: 7
                )
            )
        }

        return AnyLayout(
            HStackLayout(spacing: 7)
        )
    }

    private var mediaInfoRow: some View {
        Button(action: onShowMediaInfo) {
            HStack {
                Label(
                    "재생 정보",
                    systemImage: "info.circle"
                )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .font(.subheadline)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .frame(minHeight: 44)
    }

    private var snapshotRow: some View {
        Button(action: onCaptureSnapshot) {
            Label(
                "현재 장면 스크린샷",
                systemImage: "camera"
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .frame(minHeight: 44)
    }

    private var chooseVideoRow: some View {
        Button(action: onChooseAnotherVideo) {
            Label(
                "다른 동영상 열기",
                systemImage: "folder"
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .frame(minHeight: 44)
    }

    private var playbackRateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("재생 속도", systemImage: "speedometer")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            choiceLayout {
                ForEach(rates, id: \.self) { rate in
                    Button {
                        player.setPlaybackRate(rate)
                    } label: {
                        Text(rateLabel(rate))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                player.playbackRate == rate
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.playbackRate == rate
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(
                        maxWidth:
                            dynamicTypeSize.isAccessibilitySize
                            ? .infinity
                            : nil,
                        minHeight: 44,
                        alignment: .leading
                    )
                }
            }
        }
    }

    private var frameStepSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    "프레임 이동",
                    systemImage: "film.stack"
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Text(
                    player.isPlaying
                    ? "누르면 일시정지"
                    : "정밀 탐색"
                )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.46))
            }

            HStack(spacing: 10) {
                Button {
                    player.stepToPreviousFrame()
                } label: {
                    Label(
                        "이전 프레임",
                        systemImage: "backward.end.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(!player.canStepFrames)
                .opacity(player.canStepFrames ? 1 : 0.4)

                Button {
                    player.stepToNextFrame()
                } label: {
                    Label(
                        "다음 프레임",
                        systemImage: "forward.end.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(!player.canStepFrames)
                .opacity(player.canStepFrames ? 1 : 0.4)
            }

            Text(
                "재생 중 누르면 VLCKit이 먼저 일시정지한 뒤 한 프레임씩 이동합니다. 이전 프레임은 일부 스트림/코덱에서 지원되지 않을 수 있습니다."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.44))
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private var bookmarkSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    "북마크",
                    systemImage: "bookmark"
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if !player.playbackBookmarks.isEmpty {
                    Text("\(player.playbackBookmarks.count)개")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.46))
                }
            }

            Button {
                player.addPlaybackBookmark()
            } label: {
                HStack {
                    Image(
                        systemName:
                            player.canAddPlaybackBookmark
                            ? "bookmark.badge.plus"
                            : "bookmark.fill"
                    )

                    Text(
                        player.canAddPlaybackBookmark
                        ? "현재 위치 저장"
                        : "현재 위치 저장됨"
                    )

                    Spacer()

                    Text(player.formattedCurrentTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.58))
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!player.canAddPlaybackBookmark)
            .opacity(
                player.canAddPlaybackBookmark
                ? 1
                : 0.55
            )

            if !player.playbackBookmarks.isEmpty {
                VStack(spacing: 5) {
                    ForEach(player.playbackBookmarks) { bookmark in
                        HStack(spacing: 8) {
                            Button {
                                player.jumpToPlaybackBookmark(
                                    id: bookmark.id
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    Image(
                                        systemName:
                                            player.isCurrentPlaybackBookmark(
                                                bookmark
                                            )
                                            ? "play.circle.fill"
                                            : "play.circle"
                                    )

                                    Text(bookmark.timeText)
                                        .font(
                                            .caption.monospacedDigit()
                                                .weight(.semibold)
                                        )

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)

                            Button(role: .destructive) {
                                player.removePlaybackBookmark(
                                    id: bookmark.id
                                )
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .frame(
                                        width: 44,
                                        height: 44
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(
                                .white.opacity(0.58)
                            )
                            .accessibilityLabel("북마크 삭제")
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.07))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                        )
                    }
                }

                Button(role: .destructive) {
                    player.removeAllPlaybackBookmarks()
                } label: {
                    Label(
                        "이 영상 북마크 모두 삭제",
                        systemImage: "trash"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.58))
            } else {
                Text(
                    "원하는 장면에서 현재 위치를 저장하면 다음에 이 영상을 다시 열어도 그대로 남아 있습니다."
                )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
        }
    }

    private var abRepeatSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("A-B 반복", systemImage: "repeat")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if player.isABRepeatActive {
                    Text("반복 중")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                Button {
                    player.markABRepeatStart()
                } label: {
                    VStack(spacing: 2) {
                        Text("A 설정")
                            .font(.caption.weight(.semibold))

                        Text(player.formattedABRepeatStart)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    player.markABRepeatEnd()
                } label: {
                    VStack(spacing: 2) {
                        Text("B 설정")
                            .font(.caption.weight(.semibold))

                        Text(player.formattedABRepeatEnd)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!player.canSetABRepeatEnd)
                .opacity(player.canSetABRepeatEnd ? 1 : 0.4)

                Button {
                    player.clearABRepeat()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .disabled(player.abRepeatStartSeconds == nil)
                .opacity(
                    player.abRepeatStartSeconds == nil
                    ? 0.4
                    : 1
                )
                .accessibilityLabel("A-B 반복 해제")
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.82))

            Text(
                player.isABRepeatActive
                ? "B 지점에 도달하면 A 지점으로 돌아갑니다."
                : "A를 먼저 정한 뒤 원하는 위치에서 B를 설정합니다."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("취침 타이머", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if player.sleepTimerMode != .off {
                    Text(player.sleepTimerStatusText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            choiceLayout {
                ForEach(
                    [
                        SleepTimerMode.minutes15,
                        .minutes30,
                        .minutes60,
                        .endOfCurrentVideo
                    ]
                ) { mode in
                    Button {
                        player.setSleepTimer(mode)
                    } label: {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                player.sleepTimerMode == mode
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.sleepTimerMode == mode
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(
                        maxWidth:
                            dynamicTypeSize.isAccessibilitySize
                            ? .infinity
                            : nil,
                        minHeight: 44,
                        alignment: .leading
                    )
                }
            }

            if player.sleepTimerMode != .off {
                Button {
                    player.clearSleepTimer()
                } label: {
                    Label("타이머 해제", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private var videoDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("화면비율", systemImage: "aspectratio")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 7) {
                ForEach(VideoDisplayMode.allCases) { mode in
                    Button {
                        player.setVideoDisplayMode(mode)
                    } label: {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                player.videoDisplayMode == mode
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.videoDisplayMode == mode
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var audioTrackSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(
                "오디오 트랙",
                systemImage: "waveform.badge.magnifyingglass"
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(width: 24)

                Text("현재 트랙")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                if player.audioTrackOptions.count > 1 {
                    Menu {
                        ForEach(player.audioTrackOptions) { track in
                            Button {
                                player.selectAudioTrack(
                                    id: track.id
                                )
                            } label: {
                                Label(
                                    track.name,
                                    systemImage:
                                        track.isSelected
                                        ? "checkmark"
                                        : "circle"
                                )
                            }
                        }
                    } label: {
                        trackMenuLabel(
                            title:
                                player.selectedAudioTrackName
                        )
                    }
                } else {
                    Text(player.selectedAudioTrackName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }
            }

            if player.audioTrackOptions.isEmpty {
                Text("현재 파일에서 오디오 트랙 정보를 찾지 못했습니다.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
    }

    private var textTrackSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(
                "내장 자막 트랙",
                systemImage: "captions.bubble"
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.78))

            if player.textTrackOptions.isEmpty {
                Text("현재 영상에는 선택 가능한 내장 자막 트랙이 없습니다.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            } else {
                HStack(spacing: 8) {
                    Text("현재 자막")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))

                    Spacer()

                    Menu {
                        Button {
                            player.selectTextTrack(id: nil)
                        } label: {
                            Label(
                                "끔",
                                systemImage:
                                    player.textTrackOptions
                                        .contains(
                                            where: {
                                                $0.isSelected
                                            }
                                        )
                                    ? "circle"
                                    : "checkmark"
                            )
                        }

                        ForEach(player.textTrackOptions) { track in
                            Button {
                                player.selectTextTrack(
                                    id: track.id
                                )
                            } label: {
                                Label(
                                    track.name,
                                    systemImage:
                                        track.isSelected
                                        ? "checkmark"
                                        : "circle"
                                )
                            }
                        }
                    } label: {
                        trackMenuLabel(
                            title:
                                player.selectedTextTrackName
                        )
                    }
                }
            }
        }
    }

    private var audioSyncSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    "오디오 싱크",
                    systemImage: "waveform"
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Text(player.formattedAudioDelay)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.58))
            }

            HStack(spacing: 8) {
                Button {
                    player.adjustAudioDelay(
                        byMilliseconds: -100
                    )
                } label: {
                    Text("-0.1")
                        .frame(minWidth: 48)
                }

                Button {
                    player.resetAudioDelay()
                } label: {
                    Text(player.formattedAudioDelay)
                        .font(.caption.monospacedDigit())
                        .frame(
                            minWidth: 76
                        )
                }

                Button {
                    player.adjustAudioDelay(
                        byMilliseconds: 100
                    )
                } label: {
                    Text("+0.1")
                        .frame(minWidth: 48)
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.82))

            Text(
                "−는 소리를 앞당기고, +는 소리를 늦춥니다. 가운데 값을 누르면 0.0초로 초기화됩니다."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.44))
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private var audioOutputSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    "오디오 출력",
                    systemImage: "hifispeaker.2"
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Text(player.audioOutputMode.title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
            }

            choiceLayout {
                ForEach(AudioOutputMode.allCases) { mode in
                    Button {
                        player.setAudioOutputMode(mode)
                    } label: {
                        Text(mode.title)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                player.audioOutputMode == mode
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.audioOutputMode == mode
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(
                        maxWidth:
                            dynamicTypeSize.isAccessibilitySize
                            ? .infinity
                            : nil,
                        minHeight: 44,
                        alignment: .leading
                    )
                }
            }

            Text(
                "기본은 원본 출력을 유지합니다. 좌/우는 해당 채널만 듣고 싶을 때 사용할 수 있습니다."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.44))
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private var equalizerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    "이퀄라이저",
                    systemImage: "slider.vertical.3"
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Text(player.selectedAudioEqualizerPresetName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Menu {
                Button {
                    player.setAudioEqualizerPreset(
                        index: nil
                    )
                } label: {
                    Label(
                        "끔",
                        systemImage:
                            !player.audioEqualizerIsCustom
                            && player.audioEqualizerPresetIndex == nil
                            ? "checkmark"
                            : "circle"
                    )
                }

                Divider()

                ForEach(
                    player.audioEqualizerPresetOptions
                ) { preset in
                    Button {
                        player.setAudioEqualizerPreset(
                            index: preset.id
                        )
                    } label: {
                        Label(
                            preset.name,
                            systemImage:
                                !player.audioEqualizerIsCustom
                                && player.audioEqualizerPresetIndex
                                    == preset.id
                                ? "checkmark"
                                : "circle"
                        )
                    }
                }
            } label: {
                HStack {
                    Text(
                        player.selectedAudioEqualizerPresetName
                    )
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                    Spacer()

                    Image(
                        systemName:
                            "chevron.up.chevron.down"
                    )
                    .font(
                        .system(
                            size: 9,
                            weight: .semibold
                        )
                    )
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
            }

            if player.isAudioEqualizerEnabled {
                HStack {
                    Text("세부 조절")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Button {
                        player.resetAudioEqualizerToFlat()
                    } label: {
                        Label(
                            "평탄화",
                            systemImage: "arrow.counterclockwise"
                        )
                        .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.68))
                }

                equalizerPreampControl

                VStack(spacing: 8) {
                    ForEach(
                        player.audioEqualizerBands
                    ) { band in
                        equalizerBandControl(
                            band
                        )
                    }
                }
            }

            Text(
                player.isAudioEqualizerEnabled
                ? "프리셋을 선택한 뒤 프리앰프나 밴드를 움직이면 사용자 조절 모드로 전환됩니다."
                : "VLCKit에 포함된 프리셋을 선택하거나 끔으로 원본 음색을 유지할 수 있습니다."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.44))
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private var equalizerPreampControl: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("프리앰프")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                Text(player.formattedAudioEqualizerPreamp)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.66))
            }

            Slider(
                value: Binding(
                    get: {
                        Double(
                            player.audioEqualizerPreamp
                        )
                    },
                    set: {
                        player.setAudioEqualizerPreamp(
                            Float($0)
                        )
                    }
                ),
                in: -20...20,
                step: 0.5
            )
            .tint(.white)
            .accessibilityLabel("이퀄라이저 프리앰프")
            .accessibilityValue(
                player.formattedAudioEqualizerPreamp
            )
            .accessibilityHint(
                "위아래로 쓸어 프리앰프를 조절합니다."
            )
        }
    }

    private func equalizerBandControl(
        _ band: AudioEqualizerBandOption
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(band.frequencyText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                Text(
                    player.audioEqualizerBands.first(
                        where: { $0.id == band.id }
                    )?.amplificationText
                        ?? band.amplificationText
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.66))
            }

            Slider(
                value: Binding(
                    get: {
                        Double(
                            player.audioEqualizerBands.first(
                                where: {
                                    $0.id == band.id
                                }
                            )?.amplification
                                ?? band.amplification
                        )
                    },
                    set: {
                        player.setAudioEqualizerBand(
                            index: band.id,
                            amplification: Float($0)
                        )
                    }
                ),
                in: -20...20,
                step: 0.5
            )
            .tint(.white)
            .accessibilityLabel(
                "\(band.frequencyText) 이퀄라이저 밴드"
            )
            .accessibilityValue(
                player.audioEqualizerBands.first(
                    where: { $0.id == band.id }
                )?.amplificationText
                    ?? band.amplificationText
            )
            .accessibilityHint(
                "위아래로 쓸어 증폭값을 조절합니다."
            )
        }
    }

    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("챕터", systemImage: "list.number")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            if player.chapterOptions.count > 1 {
                HStack(spacing: 8) {
                    Button {
                        player.playPreviousChapter()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(!player.canPlayPreviousChapter)
                    .opacity(
                        player.canPlayPreviousChapter
                        ? 1
                        : 0.35
                    )

                    Menu {
                        ForEach(player.chapterOptions) { chapter in
                            Button {
                                player.selectChapter(
                                    index: chapter.id
                                )
                            } label: {
                                Label(
                                    "\(chapter.startTimeText)  \(chapter.name)",
                                    systemImage: chapter.isCurrent
                                        ? "checkmark"
                                        : "circle"
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(player.currentChapterName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)

                            Image(
                                systemName:
                                    "chevron.up.chevron.down"
                            )
                            .font(
                                .system(
                                    size: 9,
                                    weight: .semibold
                                )
                            )
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Button {
                        player.playNextChapter()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(!player.canPlayNextChapter)
                    .opacity(
                        player.canPlayNextChapter
                        ? 1
                        : 0.35
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                if let current = player.chapterOptions.first(
                    where: { $0.isCurrent }
                ) {
                    Text(
                        "현재: \(current.startTimeText) · "
                        + "\(current.name)"
                    )
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                }
            } else {
                Text("현재 영상에는 이동할 챕터가 없습니다.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
    }

    private var subtitleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("외부 자막", systemImage: "captions.bubble")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if player.subtitleWasAutoLoaded {
                    Text("자동")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let subtitleName = player.subtitleName {
                Text(subtitleName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            } else {
                Text("연결된 SRT 자막 없음")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Button(action: onChooseSubtitle) {
                Label("SRT 파일 선택", systemImage: "doc.badge.plus")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            if player.subtitleName != nil {
                subtitleDelayControls
                subtitleSizeControls
                subtitlePositionControls
            }
        }
    }

    private var subtitleDelayControls: some View {
        HStack(spacing: 8) {
            Text("싱크")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 34, alignment: .leading)

            Button {
                player.adjustSubtitleDelay(byMilliseconds: -100)
            } label: {
                Text("-0.1")
                    .frame(minWidth: 42)
            }

            Button {
                player.resetSubtitleDelay()
            } label: {
                Text(player.formattedSubtitleDelay)
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 62)
            }

            Button {
                player.adjustSubtitleDelay(byMilliseconds: 100)
            } label: {
                Text("+0.1")
                    .frame(minWidth: 42)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.82))
    }

    private var subtitleSizeControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "textformat.size")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 34)

            Button {
                player.adjustSubtitleFontScale(by: -0.1)
            } label: {
                Image(systemName: "minus")
                    .frame(minWidth: 42)
            }
            .disabled(player.subtitleFontScale <= 0.6)

            Button {
                player.resetSubtitleFontScale()
            } label: {
                Text(player.formattedSubtitleFontScale)
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 62)
            }

            Button {
                player.adjustSubtitleFontScale(by: 0.1)
            } label: {
                Image(systemName: "plus")
                    .frame(minWidth: 42)
            }
            .disabled(player.subtitleFontScale >= 1.8)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.82))
    }

    private var subtitlePositionControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("자막 위치", systemImage: "arrow.up.and.down")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            choiceLayout {
                ForEach(SubtitleVerticalPosition.allCases) { position in
                    Button {
                        player.setSubtitleVerticalPosition(position)
                    } label: {
                        Text(position.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                player.subtitleVerticalPosition == position
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .foregroundStyle(
                                player.subtitleVerticalPosition == position
                                ? Color.black
                                : Color.white
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(
                        maxWidth:
                            dynamicTypeSize.isAccessibilitySize
                            ? .infinity
                            : nil,
                        minHeight: 44,
                        alignment: .leading
                    )
                }
            }
        }
    }

    private var pictureInPictureRow: some View {
        Button {
            player.togglePictureInPicture()
        } label: {
            HStack {
                Label(
                    player.isPictureInPictureActive ? "PiP 종료" : "PiP 시작",
                    systemImage: player.isPictureInPictureActive ? "pip.exit" : "pip.enter"
                )

                Spacer()

                if !player.isPictureInPictureReady {
                    Text("준비 중")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(!player.isPictureInPictureReady)
        .opacity(player.isPictureInPictureReady ? 1 : 0.45)
        .frame(minHeight: 44)
        .accessibilityHint(
            player.isPictureInPictureActive
            ? "화면 속 화면 재생을 종료합니다."
            : "다른 앱 위에서 영상을 계속 재생합니다."
        )
    }

    private var repairRow: some View {
        Button(action: onRepairVideo) {
            HStack {
                Label("영상 복구 / 리먹스", systemImage: "wrench.and.screwdriver")

                Spacer()

                Text(
                    VideoRepairService.isAvailable
                    ? "준비됨"
                    : "연결 대기"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .frame(minHeight: 44)
        .accessibilityHint(
            "현재 영상을 새 컨테이너로 복구하거나 재인코딩합니다."
        )
    }

    private func rateLabel(_ rate: Float) -> String {
        rate == 1.0 ? "1x" : "\(rate.formatted(.number.precision(.fractionLength(0...2))))x"
    }
}
