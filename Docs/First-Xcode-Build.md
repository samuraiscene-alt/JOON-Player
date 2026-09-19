# JOON Player — First Xcode Build Runbook

Checked: 2026-09-19

이 문서는 Mac/Xcode를 처음 사용할 때 JOON Player의 첫 컴파일을 최대한 단순하게 진행하기 위한 실행 순서다.

## 1. 저장소를 Mac에 준비

GitHub에서 `samuraiscene-alt/JOON-Player` 저장소를 Mac에 clone 한다.

터미널에서 저장소 루트로 이동한 뒤 먼저:

```bash
./Scripts/check-xcode-readiness.sh
```

를 실행한다.

이 단계에서는 Xcode 프로젝트가 아직 없다는 경고가 나와도 정상이다. 소스 23개, Podfile target, VLCKit pin이 맞는지가 핵심이다.

## 2. Xcode 프로젝트 생성

`Docs/Xcode-Project-Setup.md`의 값으로 iOS App 프로젝트를 만든다.

반드시 Product Name은 `JOONPlayer`, Interface는 SwiftUI, Language는 Swift, Deployment Target은 iOS 17.0 이상, 지원 기기는 iPhone + iPad로 맞춘다.

Xcode가 만든 기본 `ContentView.swift`와 앱 entry 파일은 저장소의 기존 파일과 중복되지 않게 제거한 뒤 기존 `JOONPlayer/App` 파일을 target에 넣는다.

## 3. Source Manifest 대조

Xcode의 **Build Phases → Compile Sources**에서 `Docs/Xcode-Source-Manifest.txt`에 적힌 Swift **23개**가 모두 보이는지 확인한다. 한 파일도 빠지거나 두 번 들어가면 안 된다.

## 4. VLCKit 설치

Xcode를 닫고 저장소 루트 터미널에서:

```bash
pod install
```

을 실행한다. 그 다음부터는 `JOONPlayer.xcworkspace`를 열고 `.xcodeproj`를 직접 열어 빌드하지 않는다.

## 5. 자동 사전검사 재실행

workspace가 생긴 뒤 다시:

```bash
./Scripts/check-xcode-readiness.sh
```

를 실행한다. 전부 통과하면 첫 컴파일로 넘어간다.

## 6. 첫 Simulator 컴파일

터미널에서 자동으로 먼저 확인하려면:

```bash
./Scripts/check-xcode-readiness.sh --build
```

을 실행한다.

이 명령은 `JOONPlayer.xcworkspace`, `JOONPlayer` scheme, Debug, generic iOS Simulator, code signing disabled 조건으로 첫 컴파일을 시도한다.

## 7. 오류가 나면 처리 순서

한꺼번에 여러 곳을 고치지 않는다. 처음 나타난 컴파일 오류부터 파일 누락/Target Membership → VLCKit importer signature → Swift concurrency/actor isolation → UIKit/SwiftUI API → AVFoundation 경고 순서로 처리한다.

FFmpegKitNext는 첫 빌드에서 아직 연결하지 않으므로 `canImport(ffmpegkit)` 밖으로 관련 타입이 새지 않았는지만 확인한다.

## 8. 첫 성공 기준

첫 Simulator 빌드에서는 컴파일 완료, 링크 완료, JOON Player 실행, 홈 화면 표시, 동영상 선택 버튼 표시, 파일 선택기 호출 가능까지 성공하면 된다.

FFmpegKitNext가 아직 연결되지 않은 것은 정상이다.

## 9. 그 다음 실기기

Simulator 기본 빌드가 통과한 다음 실제 iPhone/iPad target으로 전환한다.

Signing Team과 Bundle Identifier를 설정하고 **Signing & Capabilities → Background Modes → Audio, AirPlay, and Picture in Picture**를 켠다.

실기기에서는 파일 앱 MP4 열기 → 재생/일시정지 → ±10초 → 회전 → 화면 잠금 → PiP → 외부 SRT → MKV → 최근 파일 → 앱 종료 후 이어보기 순서로 확인한다.

## 10. 첫 오류를 ChatGPT에 전달할 때

에러가 나면 전체 화면을 여러 장 보내기보다 **Issue Navigator의 가장 위 첫 오류와 그 파일/라인이 함께 보이는 화면**을 보내는 것이 가장 빠르다.

터미널 빌드라면 `error:`가 처음 나오는 부분부터 위아래 약 20~30줄 정도면 충분하다. JOON Player는 첫 컴파일 단계에서 에러를 순서대로 하나씩 제거하며 진행한다.
