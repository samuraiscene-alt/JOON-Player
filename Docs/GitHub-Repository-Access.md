# JOON Projects — GitHub Repository Access Standard

Checked: 2026-09-19

## 목적

앞으로 새 앱을 개발하거나 기존 앱을 수정할 때 ChatGPT가 해당 GitHub repository를 **읽기만 하는 것이 아니라 실제 commit/push까지 수행할 수 있는 환경**을 기본값으로 사용한다.

## 현재 확인 상태

- ChatGPT의 GitHub plugin permission: **Allow all actions**
- 따라서 ChatGPT 쪽의 읽기/쓰기 동작 권한은 이미 허용되어 있다.
- 현재 GitHub App installation에서 확인되는 repository는 `samuraiscene-alt/JOON-Player` 한 개뿐이다.
- JOON Player에서는 `push: true`가 실제로 확인되었고 commit/push도 정상 동작한다.

즉 현재 제한은 ChatGPT permission이 아니라 **GitHub App installation의 repository access 범위**다.

## 권장 GitHub App 설정

개인 계정 `samuraiscene-alt`에 설치된 ChatGPT/Codex GitHub App의 Repository access를:

```text
All repositories
```

로 설정한다.

이렇게 설정하면 기존 앱 repository뿐 아니라 앞으로 같은 GitHub 계정에 추가되는 repository도 별도로 하나씩 다시 연결하는 일을 줄일 수 있다.

## 새 앱 개발 표준

새 앱을 시작할 때:

1. 사용자가 GitHub에 앱 전용 repository를 만든다.
2. repository 이름을 ChatGPT에 알려준다.
3. ChatGPT는 작업 시작 전에 repository visibility와 default branch를 읽는다.
4. `permissions.push == true`를 확인한다.
5. 실제 파일을 읽은 뒤 수정한다.
6. commit을 생성한다.
7. `main` 또는 실제 기본 branch를 non-force 방식으로 update한다.
8. 마지막으로 commit을 다시 조회해 변경 파일을 검증한다.
9. 검증된 commit SHA를 사용자에게 알려준다.

**쓰기 권한이 확인되지 않은 repository에는 수정 성공을 주장하지 않는다.**

## 기존 앱 수정 표준

완성된 앱을 고칠 때도 동일하다.

- 새 repository를 만들지 않는다.
- 기존 repository의 최신 branch를 먼저 확인한다.
- README / handoff / 기존 코드 구조를 읽는다.
- 정상 기능을 불필요하게 다시 작성하지 않는다.
- 수정 범위를 최소화한다.
- commit 후 실제 변경 파일을 검증한다.

## Repository 접근이 안 보일 때

다음 순서로 처리한다.

1. GitHub App installation의 Repository access가 `All repositories`인지 확인한다.
2. 새 repository가 막 생성된 경우 GitHub 연결에서 다시 조회한다.
3. 조직 소유 repository라면 해당 organization에도 GitHub App이 설치되어 있는지 확인한다.
4. `Only select repositories`를 유지해야 하는 경우 해당 repository를 명시적으로 추가한다.
5. 접근이 확인되기 전에는 repository 이름을 추측해 새로 만들거나 다른 repository에 코드를 섞지 않는다.

## 보안 원칙

Repository access를 넓혀도 다음 값은 GitHub에 직접 저장하지 않는다.

- GitHub PAT
- Supabase service role key
- Apple signing private key
- 관리자 비밀번호
- API secret
- 개인 인증서

GitHub App의 repository access와 repository 안에 secret을 저장하는 것은 별개의 문제다.

## 프로젝트별 검증

Repository access를 `All repositories`로 바꾼 뒤 ChatGPT가 다음을 다시 확인한다.

- Smart Store
- QR - Attendance
- JOON Dashboard
- Digital Card
- Lotto Analyzer V2
- JOON Player
- 그 외 계정에 존재하는 앱 repository

각 repository마다:
- repository 발견 여부
- default branch
- private/public
- pull
- push
- admin/maintain 가능 여부

를 확인하고 `Docs/Mac-Project-Registry.md`를 실제 GitHub 상태로 갱신한다.
