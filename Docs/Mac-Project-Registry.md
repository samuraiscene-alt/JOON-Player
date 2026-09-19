# JOON Projects — Mac Continuity Registry

Checked: 2026-09-19

이 문서는 iPhone 중심으로 진행한 앱들을 나중에 Mac 환경에서 다시 열어 이어서 작업하기 위한 **공통 프로젝트 목록**이다.

원칙:
- 각 앱의 실제 소스는 **각 앱의 GitHub 저장소가 원본(Source of Truth)** 이다.
- 이 저장소에는 다른 앱의 소스 코드를 복사해 섞지 않는다.
- 이 문서는 프로젝트 위치와 재개 조건만 기록한다.
- 최종 개발 단계가 끝났을 때만 앱별 `FINAL_HANDOFF.md`를 만든다.
- 개발 중간에는 README / 상태 문서 / GitHub 커밋으로 이어서 작업한다.
- 비밀번호, 토큰, Supabase service role key 같은 비밀값은 GitHub 문서에 기록하지 않는다.

## 1. JOON Player

- 종류: Native iOS / iPadOS
- GitHub: `samuraiscene-alt/JOON-Player`
- Branch: `main`
- 상태: 개발 진행 중
- 핵심 기술: Swift, SwiftUI, VLCKit 4.0.0a24
- 선택적 후속 엔진: FFmpegKitNext v9.0.0
- 최소 iOS: 17.0
- Mac 필요 시점: 실제 Xcode compile / signing / iPhone 설치 / 실기기 테스트
- Mac 재개 문서:
  - `Docs/First-Xcode-Build.md`
  - `Docs/Xcode-Project-Setup.md`
  - `Docs/Xcode-Source-Manifest.txt`
  - `Docs/PreXcode-Compile-Preflight.md`
- 자동화:
  - `Scripts/generate-xcode-project.sh`
  - `Scripts/check-xcode-readiness.sh`
- 프로젝트 생성 기준: `project.yml`

Mac에서 기본 재개 순서:

```bash
git clone <JOON-Player repository>
cd JOON-Player
git pull origin main
brew install xcodegen
./Scripts/generate-xcode-project.sh
pod install
./Scripts/check-xcode-readiness.sh --build
```

실제 iPhone 설치 전에는 Signing Team / 고유 Bundle Identifier / Background Modes를 Xcode에서 확인한다.

## 2. Smart Store

- 종류: PWA / 웹앱
- 알려진 GitHub 저장소: `samuraiscene-alt/smart-store-v1`
- Branch: `main`
- Backend: Supabase
- Supabase 프로젝트명: `Smart-Store-V1`
- 상태: 개발 진행 중
- 기존 인수인계 자료:
  - `SMART_STORE_V1_통합작업_인계서_2026-09-07.txt`
  - 이후 대화에서 `smart_store4_handoff.md` 형태로 최신 작업 인계 보관
- 운영 원칙: 개발 중간마다 최종 인수인계서를 새로 만들지 않고, 앱의 최종 개발 단계에서 `SMART_STORE_FINAL_HANDOFF.md`를 한 번 만든다. 이후 큰 구조 변경이 있을 때만 갱신한다.

Mac 재개 시:
1. 저장소 clone
2. `main` 최신 상태 확인
3. 기존 handoff 파일과 README 확인
4. Supabase 연결 정보는 GitHub에 비밀키를 저장하지 않고 별도 보안 설정에서 연결
5. 기존 정상 작동 기능을 먼저 확인한 뒤 작업 재개

현재 ChatGPT GitHub 연결에서는 이 저장소에 대한 쓰기 권한이 확인되지 않았으므로, 이 문서에는 위치와 재개 원칙만 보존한다.

## 3. QR - Attendance

- 종류: PWA / 웹앱
- 프로젝트명: `QR - Attendance`
- Backend: Supabase
- Supabase 프로젝트명: `QR-Attendance`
- 확인된 구성: `index.html`, `style.css`, `app.js`, `manifest.json`, `service-worker.js`, PWA 아이콘
- 주요 기능 진행 이력: 집결지 QR / 현장 QR / 대리 QR, 행사 상태 전환/종료, 새로고침 유지, QR 회귀 테스트
- 상태: 개발 이력 존재
- GitHub 저장소명: 현재 연결된 GitHub 범위에서는 확인되지 않음

Mac 재개 전 가장 먼저 해야 할 일:
1. 실제 GitHub 저장소명을 확인
2. 저장소를 이 Registry에 추가
3. Supabase 프로젝트 `QR-Attendance` 연결 상태 확인
4. PWA service worker cache version과 배포 URL 확인
5. 정상 동작 기준을 README 또는 handoff 문서에 고정

저장소명이 확인되기 전에는 새 저장소를 추측해 만들지 않는다.

## 4. JOON Dashboard

- 종류: GitHub Pages / PWA
- 알려진 저장소명: `JOON-Dashboard`
- 용도: 개인 통합 대시보드
- 연결 대상 이력: 디지털 명함, 로또 분석기 등
- Mac에서는 웹 프로젝트이므로 저장소 clone 후 HTML/CSS/JS 기반으로 바로 이어서 작업 가능
- 현재 GitHub 연결에서는 저장소 접근 여부가 확인되지 않음

## 5. Digital Card

- 종류: GitHub Pages / PWA + Supabase
- 프로젝트명 이력: `SHINeJOON Digital Card`
- 주요 기능: 연락처 저장, 지도, 문자, 공유, Instagram, 갤러리, QR, 관리자 화면
- Mac에서는 기존 GitHub 저장소와 Supabase 프로젝트를 연결해 그대로 이어서 작업 가능
- 정확한 GitHub repository identifier는 현재 연결 범위에서 재확인 필요
- 저장소명을 추측해서 새로 만들지 않는다

## 6. Lotto Analyzer V2

- 종류: GitHub Pages / PWA
- 주요 파일:
  - `index.html`
  - `style.css`
  - `app.js`
  - `lotto_data.json`
  - `update_lotto.py`
  - `.github/workflows/update-lotto.yml`
- 자동 업데이트 기준: 매주 일요일 21:10 KST
- Mac에서는 저장소 clone 후 웹 코드와 GitHub Actions를 그대로 이어서 작업 가능
- 정확한 GitHub repository identifier는 현재 연결 범위에서 재확인 필요

## Mac 이전 상태 표

| 프로젝트 | 소스 원본 | Mac 재개 준비 |
| --- | --- | --- |
| JOON Player | GitHub `samuraiscene-alt/JOON-Player` | 준비 완료 |
| Smart Store | GitHub `samuraiscene-alt/smart-store-v1` | 소스 위치 알려짐, 현재 connector 쓰기 접근 미확인 |
| QR - Attendance | GitHub 저장소 확인 필요 | 저장소 식별 필요 |
| JOON Dashboard | `JOON-Dashboard` 이력 | connector 접근 재확인 필요 |
| Digital Card | 기존 GitHub + Supabase | repo identifier 재확인 필요 |
| Lotto Analyzer V2 | 기존 GitHub Pages 저장소 | repo identifier 재확인 필요 |

이 표에서 **확인 필요**인 항목은 소스가 없다는 뜻이 아니라, 현재 ChatGPT에 연결된 GitHub 범위에서 repository identifier 또는 쓰기 권한을 확인하지 못했다는 뜻이다.

## Mac으로 넘어갈 때의 공통 규칙

1. 새로 다시 만들지 말고 먼저 기존 GitHub 저장소를 clone한다.
2. 항상 `main` 또는 해당 프로젝트의 실제 기본 branch 최신 상태를 pull한다.
3. README / handoff / migration 문서를 먼저 읽는다.
4. Supabase project ref, URL, anon key처럼 앱 실행에 필요한 설정은 환경 설정으로 연결한다.
5. service role key, GitHub PAT, 관리자 비밀번호 같은 비밀값은 repository에 기록하지 않는다.
6. 정상 작동 중인 기능부터 재현한 뒤 새 기능을 추가한다.
7. Mac에서 구조를 크게 바꾸기 전 Git commit을 남긴다.
8. 최종 개발 단계가 끝났을 때만 앱별 `FINAL_HANDOFF.md`를 작성한다.
