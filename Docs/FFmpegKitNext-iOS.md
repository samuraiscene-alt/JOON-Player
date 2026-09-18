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
FFmpegKitNext는 기존 프로젝트의 원 저자가 이어서 유지하는 후속 프로젝트를 사용한다.

## 현재 JOON Player 코드 상태

`FFmpegKitNextRuntime`은 `#if canImport(ffmpegkit)`로 동작한다.

따라서 지금 저장소는 FFmpegKitNext 바이너리가 없어도 나머지 코드 구조를 유지하고,
나중에 Mac/Xcode에서 `ffmpegkit` 모듈을 연결하면 고급 자르기, 정확 자르기, 복구/리먹스 경로가 자동으로 활성화된다.

모든 FFmpeg 명령은 하나의 전용 serial queue를 공유한다.
FFmpeg fftools의 process-global 상태 때문에 자르기, 복구, 향후 썸네일/변환 작업을 동시에 실행하지 않도록 하기 위한 구조다.

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

## 빠른 자르기

재인코딩 없이 스트림을 복사한다.

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

## 정확 자르기

사용자가 **정확 자르기**를 선택하면 빠른 자르기와 분리된 재인코딩 경로를 사용한다.

- MP4 / MOV / M4V: AVFoundation의 `AVAssetExportPresetHighestQuality` + 정확한 `timeRange`를 우선 사용한다.
- MKV / AVI / TS / M2TS / WebM / FLV 등: FFmpegKitNext가 연결되어 있을 때 FFmpeg 재인코딩 경로를 사용한다.
- FFmpeg 경로에서는 입력을 연 뒤 `-ss`를 적용해 목표 시점까지 디코딩하므로 키프레임 기반 스트림 복사보다 정확한 컷을 만든다.
- 출력은 MP4, 영상은 FFmpeg 내장 `mpeg4` 인코더, 오디오는 `aac`를 사용한다.
- 이 방식은 재인코딩이므로 처리 시간이 길어지고 파일 크기나 화질이 달라질 수 있다.
- 외부 SRT는 포함하지 않는다.

FFmpeg 정확 자르기 명령의 핵심 구조:

```
-i <input>
-ss <start>
-t <duration>
-map 0:v:0?
-map 0:a:0?
-c:v mpeg4
-q:v 2
-c:a aac
-b:a 192k
-movflags +faststart
<output.mp4>
```

실제 컷 위치는 임의의 소수점 시간이 아니라 소스 영상의 가장 가까운 프레임 경계에 맞춰진다.

## 빠른 복구 / 리먹스

현재 파일에서 FFmpeg가 읽어낼 수 있는 영상·오디오·내장 자막 스트림을 새 MKV 컨테이너로 다시 묶는다.

```
-fflags +genpts+discardcorrupt
-err_detect ignore_err
-i <input>
-map 0:v?
-map 0:a?
-map 0:s?
-map_metadata 0
-c copy
-avoid_negative_ts make_zero
<output.mkv>
```

목적은 다음과 같다.

- 손상 패킷을 가능한 경우 건너뛰기
- 누락/비정상 타임스탬프를 가능한 범위에서 다시 생성
- 오래되거나 비정상적인 컨테이너 인덱스 문제를 새 컨테이너로 재작성
- 재인코딩 없이 원본 스트림을 최대한 보존

이 기능은 **원본 데이터를 복원하는 복구 프로그램이 아니다**.
이미 유실된 프레임, 읽을 수 없는 코덱 데이터, MP4의 핵심 메타데이터가 완전히 사라진 경우 등은 리먹스만으로 복구되지 않을 수 있다.

외부 SRT 자막은 복구본에 자동으로 합치지 않는다.
원본 안에 들어 있던 내장 자막 스트림만 가능한 경우 복사한다.

## 라이선스

FFmpegKitNext와 FFmpeg의 최종 라이선스 조건은 실제 빌드 옵션과 포함하는 외부 라이브러리에 따라 달라질 수 있다.
JOON Player 배포용 빌드를 만들 때 활성화된 라이브러리와 라이선스 파일을 별도로 점검한다.
