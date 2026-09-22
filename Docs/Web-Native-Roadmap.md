# JOON Player — Web / Native Dual-Track Roadmap

Checked: 2026-09-22

## 개발 원칙

JOON Player는 앞으로 **Web/PWA + Native iOS/iPadOS** 두 트랙으로 유지한다.

웹 버전을 먼저 만든다고 기존 Swift/VLCKit 기능을 삭제하지 않는다. 현재 `JOONPlayer/` 폴더는 Mac/Xcode 단계에서 그대로 이어서 사용한다.

## 저장소 구조

```text
JOON-Player/
├─ Web/           # Mac 없이 우선 개발·실사용하는 PWA
├─ JOONPlayer/    # 기존 Swift + SwiftUI + VLCKit Native 구현
├─ Docs/
├─ Scripts/
├─ Podfile
└─ project.yml
```

## Web 1차 범위

- 파일 앱에서 여러 영상 선택
- 서버 업로드 없이 Object URL로 로컬 재생
- 재생 / 일시정지 / ±10초
- 진행바 / 현재 시간 / 전체 시간
- 음소거
- 전체화면 fallback
- 브라우저 PiP 지원 시 PiP
- 세션 재생목록 / 이전 / 다음
- 전체 반복 / 한 곡 반복 / 셔플
- 재생 속도
- 원본 / 맞춤 / 채우기 화면비율
- A-B 반복
- 취침 타이머
- 외부 SRT 선택
- SRT 싱크 / 크기 / 위치
- 더블 탭 ±10초
- 수평 드래그 탐색
- 길게 누르는 동안 2배속
- 왼쪽 세로 드래그: 영상 밝기 오버레이
- 오른쪽 세로 드래그: iOS Safari 제약 안내 후 기기 측면 볼륨 버튼 사용
- 컨트롤 잠금
- localStorage 이어보기
- 외장 키보드 Space / ← / → / M
- PWA manifest + service worker

## Native backlog — 제외하지 않는 기능

다음은 웹에서 포기하는 기능이 아니라 Mac/Xcode에서 계속 개발·검증할 기능이다.

- VLCKit 기반 MKV / AVI / TS / M2TS / FLV 광범위 코덱
- iOS security-scoped bookmark 기반 파일 재접근
- 앱 재실행 후 저장 재생목록의 원본 파일 복원
- 시스템 화면 밝기 직접 제어
- 오디오 트랙 / 내장 자막 트랙 / 챕터
- 오디오 sync / output / EQ
- 이전/다음 프레임
- VLC 원본 프레임 snapshot
- FFmpegKitNext 자르기 / 복구 / remux
- 네이티브 PiP 세부 제어
- TestFlight / App Store 빌드

## 웹 코덱 정책

웹에서는 확장자가 아니라 Safari가 **내부 영상·오디오 코덱을 실제로 디코딩할 수 있는지**가 재생 성공을 결정한다.

MP4/H.264/AAC를 1차 기준으로 테스트한다. MKV를 파일 선택에서 막지는 않지만 웹에서 실패하면 Native 버전에서 VLCKit로 지원한다.

## 데이터 정책

웹 버전은 영상 파일을 서버에 업로드하지 않는다.

- 현재 영상: 브라우저 Object URL
- 설정: localStorage
- 이어보기: 파일명 + 파일 크기 + lastModified fingerprint
- 재생목록: 현재 브라우저 세션의 File 객체

iOS Safari는 네이티브 security-scoped bookmark와 같은 방식으로 파일 접근 권한을 영구 저장할 수 없으므로, 앱 재실행 후 파일 자동 복원은 Native 기능으로 유지한다.

## 다음 순서

1. `Web/` 정적 배포
2. iPhone Safari에서 MP4 재생 확인
3. 홈 화면 추가 / standalone 확인
4. 제스처 실기기 튜닝
5. SRT 인코딩/싱크 테스트
6. 최종 앱 아이콘 PNG 세트 적용
7. Mac 준비 시 `JOONPlayer/` Native 개발 재개
