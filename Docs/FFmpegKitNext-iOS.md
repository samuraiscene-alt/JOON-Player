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
나중에 Mac/Xcode에서 `ffmpegkit` 모듈을 연결하면 고급 자르기, 정확 자르기, 빠른 복구, 2차 재인코딩 복구 경로가 자동으로 활성화된다.

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

## 정확 자르기

사용자가 **정확 자르기**를 선택하면 빠른 자르기와 분리된 재인코딩 경로를 사용한다.
MP4 / MOV / M4V는 AVFoundation을 우선 사용하고, 기타 형식은 FFmpegKitNext 연결 시 재인코딩한다.

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

원본 스트림을 다시 압축하지 않기 때문에 빠르고 화질 손실이 거의 없지만, 손상된 스트림 자체나 출력 컨테이너 호환 문제 때문에 실패할 수 있다.

## 2차 재인코딩 복구

빠른 복구가 실패했을 때 사용자가 **2차 재인코딩**을 선택할 수 있다.

```
-fflags +genpts+discardcorrupt
-err_detect ignore_err
-analyzeduration 100M
-probesize 100M
-i <input>
-map 0:v:0?
-map 0:a:0?
-map_metadata 0
-c:v mpeg4
-q:v 4
-c:a aac
-b:a 160k
-max_muxing_queue_size 4096
-movflags +faststart
-avoid_negative_ts make_zero
<output.mp4>
```

이 경로는 다음을 목표로 한다.

- 스트림 복사 대신 디코딩 가능한 프레임을 새 영상으로 재인코딩
- 더 긴 probe/analyze 구간으로 불완전한 스트림 정보 재탐색
- 손상 패킷을 가능한 범위에서 건너뛰기
- 표준 MP4 + MPEG-4 video + AAC로 다시 저장해 컨테이너/코덱 복사 호환 문제 회피

대신 처리 시간이 오래 걸리고 영상이 다시 압축되며, 파일 크기와 화질이 달라질 수 있다.
2차 복구에서는 내장 자막을 복사하지 않는다.

이 방식도 이미 유실된 프레임, 읽을 수 없는 헤더, 완전히 사라진 MP4 moov 메타데이터 등을 만들어내는 복원 기술은 아니다.

## 라이선스

FFmpegKitNext와 FFmpeg의 최종 라이선스 조건은 실제 빌드 옵션과 포함하는 외부 라이브러리에 따라 달라질 수 있다.
JOON Player 배포용 빌드를 만들 때 활성화된 라이브러리와 라이선스 파일을 별도로 점검한다.
