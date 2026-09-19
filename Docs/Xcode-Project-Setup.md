# JOON Player — Xcode Project Setup

Checked: 2026-09-19

이 문서는 Mac/Xcode를 준비했을 때 현재 GitHub 저장소를 그대로 iOS 앱 프로젝트로 연결하기 위한 기준 문서다.

## 1. Xcode 프로젝트 기본값

새 iOS App 프로젝트를 만들 때 다음 값을 사용한다.

- Product Name: `JOONPlayer`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment Target: iOS 17.0
- Supported devices: iPhone + iPad
- App lifecycle: SwiftUI `App`
- Entry point: `JOONPlayer/App/JOONPlayerApp.swift`
- Root view: `JOONPlayer/App/ContentView.swift`

Podfile의 target 이름도 `JOONPlayer`이므로 Xcode target 이름을 다르게 만들지 않는다.

Bundle Identifier와 Signing Team은 실제 Apple Developer 계정을 연결하는 단계에서 정한다.

## 2. 폴더 구조

현재 저장소의 소스 구조는 이미 Xcode 그룹 구조로 사용하기에 충분하다. 파일을 다른 폴더로 재배치하지 않는다.

```text
JOONPlayer/
├─ App/
├─ Editing/
├─ File/
├─ Player/
└─ Settings/
```

Xcode에서 위 폴더 구조를 그대로 보이게 구성한다.

현재 Swift 소스는 총 **23개**이며 전부 `JOONPlayer` 앱 target의 Compile Sources에 포함되어야 한다.

정확한 파일 목록은 `Docs/Xcode-Source-Manifest.txt`를 기준으로 확인한다.

## 3. Target Membership

### JOONPlayer target에 반드시 포함

- `JOONPlayer/App/*.swift`
- `JOONPlayer/Editing/*.swift`
- `JOONPlayer/File/*.swift`
- `JOONPlayer/Player/*.swift`
- `JOONPlayer/Settings/*.swift`
- Xcode에서 생성할 `Assets.xcassets`

특히 `FFmpegKitNextRuntime.swift`도 처음부터 target에 포함한다.

FFmpegKitNext가 아직 연결되지 않았더라도 파일 내부가 `#if canImport(ffmpegkit)`로 보호되어 있으므로 소스 자체를 빼지 않는다.

### 앱 target에 포함하지 않음

다음 파일은 문서나 빌드 관리 파일이므로 Target Membership을 켜지 않는다.

- `README.md`
- `Docs/*`
- `Podfile`
- `.gitignore`

## 4. CocoaPods / VLCKit

저장소 루트의 기존 Podfile을 그대로 사용한다.

```ruby
platform :ios, '17.0'
use_frameworks!

target 'JOONPlayer' do
  pod 'VLCKit', '4.0.0a24'
end
```

Xcode 프로젝트를 저장소 루트에 만든 뒤:

```bash
pod install
```

을 실행한다.

그 이후에는 `.xcodeproj`가 아니라 CocoaPods가 생성한 `.xcworkspace`를 열어 빌드한다.

현재 `.gitignore` 정책상:

- `Pods/`는 커밋하지 않는다.
- 생성된 `.xcworkspace`도 커밋하지 않는다.
- 실제 `.xcodeproj`는 커밋 대상이다.

## 5. 첫 컴파일에서는 FFmpegKitNext를 연결하지 않아도 됨

첫 Xcode 컴파일 목표는 **VLCKit 기반 재생 앱 자체를 먼저 빌드하는 것**이다.

FFmpegKitNext는 source-only 후속 의존성이므로 첫 컴파일 전에 억지로 연결하지 않는다.

현재 코드에서는 모듈이 없으면:

- 빠른 FFmpeg 자르기 경로
- 정확 자르기의 FFmpeg fallback
- 빠른 복구 / 리먹스
- 2차 재인코딩 복구

가 자동으로 비활성/연결 대기 상태가 된다.

첫 기본 빌드가 안정된 뒤 `Docs/FFmpegKitNext-iOS.md` 순서대로 로컬 package/XCFramework를 연결한다.

## 6. Signing & Capabilities

실기기에서 PiP까지 확인하려면 Xcode target에서:

**Signing & Capabilities → Background Modes**

를 추가하고 다음 항목을 활성화한다.

- Audio, AirPlay, and Picture in Picture

파일 선택은 SwiftUI `fileImporter`와 security-scoped URL을 사용하므로 별도 사진/카메라 권한은 요구하지 않는다.

현재 스크린샷/자르기/복구 저장도 앱이 Photos API로 직접 쓰는 방식이 아니라 iOS 공유 시트를 사용하므로 사진 라이브러리 권한 문구를 선제적으로 추가하지 않는다.

## 7. Xcode가 새로 만드는 파일

새 프로젝트 생성 시 Xcode가 만드는 항목 중 다음은 유지한다.

- `JOONPlayer.xcodeproj`
- `Assets.xcassets`
- 프로젝트 build settings / signing 설정

Xcode가 기본으로 생성한 `ContentView.swift`와 앱 entry 파일은 저장소의 기존 파일과 중복되므로 새 기본 파일의 내용을 사용하지 않는다.

저장소에 이미 있는:

- `JOONPlayer/App/ContentView.swift`
- `JOONPlayer/App/JOONPlayerApp.swift`

를 실제 target 소스로 사용한다.

Preview Content가 자동 생성되더라도 현재 JOON Player에는 필요하지 않으므로 첫 컴파일에 필수 항목으로 취급하지 않는다.

## 8. 첫 빌드 전 체크리스트

1. Xcode target 이름이 정확히 `JOONPlayer`인지 확인.
2. Deployment Target이 iOS 17.0인지 확인.
3. `Docs/Xcode-Source-Manifest.txt`의 Swift 23개가 전부 target에 들어갔는지 확인.
4. 중복 `ContentView.swift` / 중복 `JOONPlayerApp.swift`가 없는지 확인.
5. `pod install` 후 workspace로 열었는지 확인.
6. `import VLCKit`가 정상 인식되는지 확인.
7. 첫 빌드에서는 FFmpegKitNext 미연결 상태를 정상 상태로 취급.
8. Swift concurrency warning/error를 숨기지 않고 그대로 수집.
9. 첫 컴파일 오류는 한 번에 여러 곳을 추측 수정하지 말고 에러 순서대로 수정.
10. Simulator 통과 후 실제 iPhone/iPad에서 파일 앱 접근, 재생, PiP, 회전, 제스처를 검증.

## 9. 현재 프로젝트에 별도 리소스 파일은 없음

현재 저장소에는 앱 아이콘/색상 asset catalog, 별도 plist, JSON 번들 리소스, 로컬 영상 샘플을 넣어두지 않았다.

따라서 첫 프로젝트 생성 시 **소스 23개 + Xcode 기본 Assets.xcassets + VLCKit 의존성**이 최소 구성이다.

테스트용 영상은 repository에 커밋하지 않고 실제 기기의 파일 앱에서 선택한다.

## 10. 첫 컴파일의 성공 기준

첫 단계 성공 기준은 다음이다.

- Xcode가 모든 Swift 소스를 컴파일
- VLCKit framework 링크 성공
- 앱이 Simulator 또는 실기기에서 실행
- 홈 화면이 표시
- 파일 선택기가 열림

이 단계에서는 FFmpegKitNext 복구/고급 자르기가 동작하지 않아도 실패로 보지 않는다.

그 다음 실제 영상 한 개를 열어 재생 화면까지 들어간 뒤 기능별 실기기 검증으로 넘어간다.
