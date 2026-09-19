# JOON Projects — Backup and Handoff Policy

Checked: 2026-09-19

## 목적

iPhone에서 작업하든 Mac에서 작업하든 프로젝트를 다시 시작하지 않고 같은 코드베이스를 이어서 사용한다.

## 1. GitHub가 원본

각 프로젝트는 GitHub repository의 최신 기본 branch를 원본으로 본다.

기기 안에만 있는 수정본을 장기간 방치하지 않는다. 의미 있는 변경은 commit + push한다.

## 2. 앱별 repository 분리

Smart Store, QR Attendance, JOON Player, Digital Card, Lotto 등은 서로 다른 앱이다.

소스 코드를 한 repository에 합치지 않는다. 공통 registry 문서만 한 곳에서 관리할 수 있다.

## 3. 개발 중 handoff와 최종 handoff 구분

개발 중:
- README
- 상태 문서
- commit history
- migration / setup 문서

를 사용한다.

최종 개발 단계:
- `<PROJECT>_FINAL_HANDOFF.md`

를 한 번 작성한다.

큰 구조 변경이 생겼을 때만 이후 갱신한다.

## 4. Mac 이전에 반드시 남길 정보

- repository 이름
- 기본 branch
- 앱 종류: PWA / Native
- backend 및 Supabase project name/ref
- build/install 방법
- 핵심 파일 목록
- 현재 완료 기능
- 다음 작업
- 알려진 문제
- 배포 URL 또는 App target
- 자동화/Actions
- secret을 제외한 환경 변수 이름

## 5. 절대 GitHub에 넣지 않는 정보

- GitHub Personal Access Token
- Supabase service role key
- Apple signing private key
- 관리자 비밀번호
- 개인 인증서 원본
- 기타 비밀키

## 6. 작업 재개 순서

1. repository clone
2. latest default branch pull
3. README / handoff 읽기
4. 의존성 설치
5. 현재 정상 상태 재현
6. 다음 작업 시작
7. commit
8. push

## 7. 프로젝트 삭제 전 확인

대화방이나 iPhone의 바로가기를 지우는 것은 repository 삭제와 별개다.

프로젝트를 삭제하기 전에는:
- GitHub repository 존재
- 최신 변경 push
- handoff 또는 README 최신 상태
- Supabase 프로젝트 존재

를 확인한다.
