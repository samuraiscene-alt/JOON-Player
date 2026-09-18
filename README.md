# JOON Player

JOON Player는 iPhone / iPad 중심의 개인용 동영상 플레이어 프로젝트입니다.

## 현재 개발 단계

Phase 2 — 로컬 재생 + 외부 SRT 자막

현재 포함된 기능:

- 파일 앱에서 동영상 선택
- MobileVLCKit 기반 재생 구조
- MP4 / MOV / MKV / AVI / M4V / TS / M2TS / WebM / FLV 선택 허용
- 재생 / 일시정지
- 10초 뒤로 / 10초 앞으로
- 진행 바 + 현재 시간 / 전체 시간
- 세로 / 가로 화면에 따른 자동 레이아웃
- 가로 재생 시 컨트롤 자동 숨김
- 심플한 iOS 스타일 스피커 아이콘
- 스피커 아이콘을 누르면 볼륨 팝업 표시
- 원터치 뮤트 / 이전 볼륨 복원
- 상단 오른쪽 톱니바퀴 → 빠른 설정 패널
- 재생 속도 변경
- 외부 SRT 자막 직접 선택
- 영상과 동일한 파일명의 SRT 자동 연결 시도
- 자막 싱크 -10초 ~ +10초 조절
- 자막 싱크 0.1초 단위 빠른 조절
- 미완료 / 일부 손상 영상도 우선 재생 시도
- 실제 VLC 오류가 발생했을 때만 오류 안내
- Supabase 사용 안 함

## 자막 자동 연결

예를 들어 아래 두 파일이 같은 폴더에 있고 파일 제공자가 형제 파일 접근을 허용하면 자동 연결을 시도합니다.

```
movie.mkv
movie.srt
```

iCloud Drive나 외부 파일 제공자의 권한 정책 때문에 같은 폴더의 SRT를 앱이 직접 읽지 못하는 경우에는 빠른 설정의 **SRT 파일 선택**으로 직접 연결할 수 있습니다.

## 파일 처리 원칙

영상은 기본적으로 iOS 파일 앱 / iCloud Drive / 내 iPhone / 외장 저장장치에 있는 파일을 직접 선택해 재생합니다.
앱 내부로 강제 복사하지 않습니다.

## 의존성

현재 재생 엔진은 MobileVLCKit을 사용합니다.

```ruby
pod 'MobileVLCKit'
```

## 나중에 Mac / Xcode 환경에서 시작하는 방법

1. Xcode에서 iOS App 프로젝트 생성
   - Product Name: `JOONPlayer`
   - Interface: SwiftUI
   - Language: Swift
   - iOS 17+
2. 이 저장소의 `JOONPlayer` 폴더를 프로젝트에 추가
3. 저장소 루트의 `Podfile` 사용
4. CocoaPods 설치 후 `pod install`
5. 생성된 `.xcworkspace`를 열어 빌드

## 다음 개발 순서

1. 화면 잠금
2. 화면비율 설정
3. PiP
4. 이어보기
5. 자막 표시 크기 / 위치 세부 설정
6. 영상 구간 자르기
7. 필요할 때만 Supabase 기능 검토

## 설계 원칙

- Supabase 의존 기능은 최대한 후순위
- 정상 작동하는 기능은 불필요하게 건드리지 않음
- 세로 / 가로 / 화면 크기 / iPhone / iPad에 맞춰 자동 적응
- 전체화면은 영상 중심, 컨트롤은 필요할 때만 표시
- UI는 얇고 심플한 iOS 스타일
