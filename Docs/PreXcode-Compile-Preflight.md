# JOON Player — Pre-Xcode Compile Preflight

Checked: 2026-09-19

This pass reviews source-level compile risks before creating the real Xcode project. It is not a substitute for an Xcode/iOS SDK build.

## VLCKit pin verified

The project Podfile pins:

```ruby
pod 'VLCKit', '4.0.0a24'
```

The VideoLAN VLCKit repository snapshot at commit:

```text
440dc1df19d181b500ae414762671701d192bcf8
```

contains `Packaging/podspecs/VLCKit.podspec` with version `4.0.0a24`. That podspec points to the 2026-08-31 VLCKit binary archive.

The same source snapshot contains the APIs JOON Player currently depends on:

- `gotoNextFrame`
- `gotoPreviousFrame`
- `saveVideoSnapshotAt:withWidth:andHeight:`
- `currentVideoSubTitleDelay`
- `currentSubTitleFontScale`
- `currentAudioPlaybackDelay`
- `audioStereoMode`
- `equalizer`
- `audioTracks`, `videoTracks`, `textTracks`
- chapter enumeration / selection APIs
- `VLCPictureInPictureDrawable`
- `VLCPictureInPictureMediaControlling`
- `VLCPictureInPictureWindowControlling`
- `VLCAudioEqualizer.presets`, preamp and band APIs

No VLCKit version bump is required for the features currently in the repository.

## Swift concurrency hardening

`PlayerViewModel` is `@MainActor`, but VLCKit delegate callbacks are Objective-C callbacks and are not documented as main-thread-only. VideoLAN's own PiP example explicitly dispatches player delegate UI work to the main queue.

For that reason:

- VLCKit imports used by the player bridge are marked `@preconcurrency`.
- `VLCMediaPlayerDelegate` witnesses are `nonisolated`.
- Delegate callbacks immediately hop to `MainActor` before changing published state or calling actor-isolated player helpers.
- The old direct call from `PlayerViewModel.deinit` to an actor-isolated cleanup method was removed. Under Swift 6 strict concurrency, a normal `deinit` is nonisolated and calling a main-actor method from it is a compile error.
- `deinit` now performs only direct resource cleanup using its stored values.

## UIKit callback cleanup

The zero-size asynchronous drawable-size update in `VLCVideoView.makeUIView` was removed. `updateUIView` already applies the real size when SwiftUI lays out the view.

The hardware keyboard responder now uses an explicit `Task { @MainActor ... }` instead of `DispatchQueue.main.async`, reducing ambiguity under Swift strict-concurrency checking.

## Existing intentional concurrency bridges

These remain intentionally in place until Xcode can compile the full target:

- `FFmpegKitNextRuntime` uses `@preconcurrency import ffmpegkit` because FFmpegKitNext is Objective-C and callback-based.
- AVFoundation trim exporters use `nonisolated(unsafe)` for the local `AVAssetExportSession` captured by the legacy completion callback. This is a narrow compatibility bridge for the iOS 17 deployment target.
- PiP protocol conformance remains behind `@preconcurrency`; the exact imported Swift signatures must still be confirmed by the real Xcode toolchain.

## Remaining build-time checks

When the Xcode project is created, enable strict concurrency warnings and verify:

1. Swift language mode selected by the generated Xcode project.
2. VLCKit Objective-C-to-Swift imported signatures, especially PiP seek completion/async bridging.
3. `AVAssetExportSession.exportAsynchronously` warnings on the chosen Xcode SDK.
4. FFmpegKitNext local module import and callback annotations after its XCFramework/SPM package is connected.
5. PiP capability: Background Modes → Audio, AirPlay, and Picture in Picture.
6. Real-device behavior for VLC delegate callback ordering, frame step, snapshot and security-scoped files.

The repository still has no `.xcodeproj`, so there is no claim of a successful iOS compile yet.
