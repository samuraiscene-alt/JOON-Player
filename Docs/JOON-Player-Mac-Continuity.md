# JOON Player — Mac Continuity

Checked: 2026-09-19

이 문서는 현재 iPhone 중심 개발에서 Mac/Xcode 환경으로 넘어갈 때 JOON Player를 **새로 만들지 않고 그대로 이어서 작업**하기 위한 기준이다.

## Source of Truth

- Repository: `samuraiscene-alt/JOON-Player`
- Default branch: `main`
- 실제 소스 원본은 GitHub의 최신 `main`
- 대화 내용보다 GitHub 최신 코드와 repository 문서를 우선한다.

## 현재 저장 구조

```text
JOON-Player/
├─ Web/           # Mac 없이 우선 완성하는 PWA
├─ JOONPlayer/    # 보존된 Native Swift/iOS 구현
│  ├─ App/
│  ├─ Editing/
│  ├─ File/
│  ├─ Player/
│  └─ Settings/
├─ Docs/
├─ Scripts/
├─ Podfile
├─ project.yml
└─ README.md
```

현재 Swift app source는 23개이며 `Docs/Xcode-Source-Manifest.txt`가 기준 목록이다.

## Mac에서 절대 새로 구현하지 않을 것

다음 기능은 이미 현재 repository에 구현되어 있으므로 Mac에서 처음부터 다시 만들지 않는다.

- VLCKit 기반 재생
- MP4/MOV/MKV/AVI/M4V/TS/M2TS/WebM/FLV 파일 선택
- 외부 SRT
- 자막 크기/위치/싱크
- 재생 속도
- 화면비율
- PiP
- 재생 목록 / 저장 재생 목록
- 이어보기
- 북마크
- A-B repeat
- sleep timer
- 오디오 트랙 / 자막 트랙 / 챕터
- 오디오 sync / output / EQ
- frame step
- snapshot
- 빠른 설정 accordion
- 외장 키보드 단축키
- VoiceOver / Dynamic Type 보강
- 사용자 퀵 액션
- 설정 저장 정책 / 설정 초기화
- 자르기 / 복구 코드 경로
- 임시 파일 cleanup
- Xcode preflight / project generation scripts

Mac에서는 먼저 **현재 코드를 compile 가능하게 만드는 작업**부터 한다.

## 첫 Mac 세션 순서

```bash
git clone <repository URL>
cd JOON-Player
git pull origin main

brew install xcodegen
./Scripts/generate-xcode-project.sh

pod install

./Scripts/check-xcode-readiness.sh
./Scripts/check-xcode-readiness.sh --build
```

첫 compiler error가 나오면 위에서부터 한 개씩 처리한다.

## FFmpegKitNext

첫 compile에서는 FFmpegKitNext를 연결하지 않아도 정상이다.

현재 `FFmpegKitNextRuntime.swift`는 `#if canImport(ffmpegkit)`로 보호되어 있다.

VLCKit 기본 빌드가 성공한 뒤:
- `Docs/FFmpegKitNext-iOS.md`
를 기준으로 FFmpegKitNext를 연결한다.

## 실기기 전환

Simulator compile 성공 뒤 iPhone/iPad에서:
- Signing Team
- 고유 Bundle Identifier
- Background Modes → Audio, AirPlay, and Picture in Picture

를 설정한다.

그 다음:
1. MP4
2. MKV
3. 외부 SRT
4. PiP
5. 화면 회전
6. 제스처
7. 이어보기
8. 재생 목록
9. snapshot / frame step
10. 자르기 / 복구

순서로 검증한다.

## 보존 규칙

- 정상 작동 코드는 이유 없이 대규모 refactor하지 않는다.
- Mac에서 Xcode가 생성한 DerivedData / Pods는 Git에 올리지 않는다.
- 실제 project source와 `.xcodeproj` 변경은 Git에 기록한다.
- `.xcworkspace`는 현재 gitignore 정책을 유지한다.
- 기능 단위 수정마다 commit을 남긴다.
- 최종 완성 단계에서만 `JOON_PLAYER_FINAL_HANDOFF.md`를 만든다.


## Web → Mac 전환 원칙

Web/PWA 개발을 진행하는 동안 Native 코드는 삭제하거나 웹 코드로 덮어쓰지 않는다.

웹에서 먼저 검증한 다음 항목은 Mac/Xcode 단계에서 기존 Swift 구조에 반영할 수 있다.

- 화면 배치
- 제스처 정책
- 재생 컨트롤 UX
- 자막 조절 UX
- 재생 목록 UX
- 설정 기본값

브라우저 한계 때문에 웹에서 구현하지 못한 항목은 `Docs/Web-Native-Roadmap.md`의 Native backlog를 기준으로 계속 개발한다.
