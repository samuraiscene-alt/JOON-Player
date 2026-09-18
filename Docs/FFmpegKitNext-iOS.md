# FFmpegKitNext iOS integration

JOON Player의 고급 자르기 / 복구 엔진은 **FFmpegKitNext**를 기준으로 준비한다.

## 선택한 엔진

- Upstream: `arthenica/ffmpeg-kit-next`
- Pin: `v9.0.0`
- FFmpeg: `9.0.1`
- 확인 기준일: 2026-09-18
- 배포 형태: source-only
- Apple API: Objective-C API exposed through the `ffmpegkit` framework module

기존 `ffmpeg-kit`은 retired 상태이므로 새 앱 의존성으로 다시 채택하지 않는다.
FFmpegKitNext는 기존 프로젝트의 원 저자가 이어서 유지하는 공식 후속 프로젝트를 사용한다.

## 현재 JOON Player 코드 상태

`AdvancedVideoTrimService`는 `#if canImport(ffmpegkit)`로 작성되어 있다.

따라서 지금 저장소는 FFmpegKitNext 바이너리가 없어도 컴파일 가능한 구조를 유지하고,
나중에 Mac/Xcode에서 `ffmpegkit` 모듈을 연결하면 MKV/AVI/TS/M2TS/WebM/FLV 자르기 경로가 자동으로 활성화된다.

MP4/MOV/M4V는 기존 AVFoundation 빠른 자르기를 우선 사용하고,
그 경로가 실패하면서 FFmpegKitNext가 연결되어 있으면 FFmpeg 스트림 복사 방식으로 한 번 더 시도한다.

## Mac/Xcode 단계

FFmpegKitNext v9.0.0은 prebuilt binary를 제공하지 않는다.
Mac에서 소스를 직접 빌드해야 한다.

공식 문서의 권장 Nix 방식:

```bash
git clone https://github.com/arthenica/ffmpeg-kit-next.git
cd ffmpeg-kit-next
git checkout v9.0.0

./nix-ios.sh -p xcode26 -x --spm
```

빌드가 끝나면 `prebuilt` 아래에 생성되는 iOS XCFramework + local `Package.swift` 폴더를 Xcode 프로젝트에 Local Package로 추가한다.

FFmpegKitNext 공식 Apple 문서는 Xcode 26.0+와 Command Line Tools를 요구한다.

## 1차 FFmpeg 빠른 자르기 명령 구조

JOON Player는 재인코딩 없이 스트림을 복사하는 방식부터 사용한다.

```
-ss <start>
-i <input>
-t <duration>
-map 0:v:0?
-map 0:a?
-map_metadata 0
-c copy
-avoid_negative_ts make_zero
<output>
```

추가로 손상 구간을 가능한 한 넘겨 진행하도록:

```
-fflags +discardcorrupt
-err_detect ignore_err
```

를 사용한다.

이 방식은 빠르고 원본 화질을 다시 압축하지 않지만, 코덱의 키프레임 위치 때문에 시작점이 프레임 단위로 완전히 정확하지 않을 수 있다.
정확한 프레임 컷은 이후 선택형 재인코딩 경로로 분리한다.

외부 SRT 자막은 현재 새 영상에 포함하지 않는다.

## 동시 실행 원칙

FFmpeg의 fftools 계층은 전역 상태를 사용하므로 JOON Player는 FFmpeg 작업을 전용 serial queue 한 곳에서만 실행하도록 한다.
향후 썸네일 생성, 복구, 변환 기능이 추가되어도 같은 큐를 공유해야 한다.

## 라이선스

FFmpegKitNext와 FFmpeg의 최종 라이선스 조건은 실제 빌드 옵션과 포함하는 외부 라이브러리에 따라 달라질 수 있다.
JOON Player 배포용 빌드를 만들 때 활성화된 라이브러리와 라이선스 파일을 별도로 점검한다.
