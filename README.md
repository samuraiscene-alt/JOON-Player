# JOON Player

JOON Player는 iPhone / iPad 중심의 개인용 동영상 플레이어 프로젝트입니다.

## 현재 개발 단계

Phase 1 — 로컬 재생 골격 + 기본 iOS 스타일 컨트롤

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
- 미완료 / 일부 손상 영상도 우선 재생 시도
- 실제 VLC 오류가 발생했을 때만 오류 안내
- Supabase 사용 안 함

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

1. 외부 SRT 자막 불러오기
2. 같은 이름의 SRT 자동 연결
3. 자막 싱크 조절
4. 화면 잠금
5. 화면비율 설정
6. PiP
7. 이어보기
8. 영상 구간 자르기
9. 필요할 때만 Supabase 기능 검토

## 설계 원칙

- Supabase 의존 기능은 최대한 후순위
- 정상 작동하는 기능은 불필요하게 건드리지 않음
- 세로 / 가로 / 화면 크기 / iPhone / iPad에 맞춰 자동 적응
- 전체화면은 영상 중심, 컨트롤은 필요할 때만 표시
- UI는 얇고 심플한 iOS 스타일
