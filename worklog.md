# 작업 로그

---

## 2026-06-19 (세션 5) — EC2 배포 완료

### 작업 내용
- IAM user `jwko-bot` Access Key로 로컬 AWS credentials 설정 (`~/.aws/credentials`)
- boto3 pip 설치
- `deploy2.py` 경로 수정 (`/tmp/app.py` → 상대경로 `app.py`)
- Desktop Commander로 `deploy2.py` 실행 (71초 소요)
  - Step 1: pip install (flask, pyotp, qrcode[pil]) ✅
  - Step 2: app.py 5청크 전송 → decode → 365줄 확인 ✅
  - Step 3: nginx config 작성 ✅
  - Step 4: systemd service 파일 작성 ✅
  - Step 5: auth-server 서비스 시작 (active) ✅
  - Step 6: nginx reload ✅
  - Step 7: 포트 확인 (8081, 8090 확인됨, 8080 누락)
- `fix_nginx.py` 실행: sites-enabled 링크 이미 있었음, nginx reload 후 8080 오픈
- `http://54.174.199.241:8080` HTTP 200 + 커스텀 로그인 페이지 응답 확인 ✅

### 현재 상태
| 항목 | 상태 |
|------|------|
| EC2 Flask 인증 프록시 | ✅ 8090 포트, active |
| nginx (8080) | ✅ 외부 접근 가능 |
| code-server (8081) | ✅ 내부 실행 중 |
| 로그인 페이지 | ✅ http://54.174.199.241:8080 |
| 브라우저 실 사용 검증 | ❌ 미완 (직접 접속 필요) |

### 다음 세션에서 할 일
1. 브라우저에서 `http://54.174.199.241:8080` 접속
2. `admin` / `admin123` 로그인 → Google Authenticator QR 등록
3. TOTP 입력 → code-server 접근 확인
4. `/auth/admin` 페이지 기능 확인 (사용자 추가/삭제/2FA 리셋)

---

## 2026-06-19 (세션 4)

### 작업 내용
- Desktop Commander 플러그인 설치 후 연결 확인
- `claude.md`, `todo.md`, `worklog.md` → `dev-server-automation/` 폴더에 복사
- `.git/config.lock` 삭제 (잠금 파일 제거)
- `git config --global core.longpaths true` (Windows MAX_PATH 우회)
- `git init` + `git add . && git commit` 성공 (16 files, root-commit 6c64b38)
- GitHub username 확인: `ysko1462`
- Python 스크립트로 GitHub API 호출 → `ysko1462/dev-server-automation` repo 생성
- `git push -u origin main` 성공

### 현재 상태
| 항목 | 상태 |
|------|------|
| GitHub repo | ✅ https://github.com/ysko1462/dev-server-automation |
| claude.md / todo.md / worklog.md | ✅ repo에 포함되어 push됨 |
| EC2 배포 (deploy2.py 실행) | ❌ 아직 미완 |

### 다음 세션에서 할 일
1. CloudShell 열기 → `/tmp/deploy2.py` 확인 후 `python3 /tmp/deploy2.py` 실행
2. 배포 완료 후 `http://54.174.199.241:8080` 동작 검증

---

## 2026-06-19 (세션 3)

### 작업 내용
- 이전 세션에서 CloudShell 탭들이 frozen → 탭 667779425 활성 확인
- `/tmp/app.py` 상태 확인: 365줄, syntax valid ✅
- `deploy2.py` base64 PART1 echo → `/tmp/d2.b64` 생성
- PART2 echo + decode + syntax check 명령 전송
- Chrome 확장 연결 끊김으로 결과 확인 불가
- `claude.md`, `todo.md`, `worklog.md` 파일 생성

### 현재 상태
| 항목 | 상태 |
|------|------|
| `/tmp/app.py` (CloudShell) | ✅ 존재, 365줄, syntax valid |
| `/tmp/deploy2.py` (CloudShell) | ❓ 명령 전송됐으나 미확인 |
| EC2 배포 | ❌ 미완 (deploy2.py 실행 전) |
| http://54.174.199.241:8080 | ❌ 아직 커스텀 로그인 페이지 미적용 |

### 다음 세션에서 할 일
1. CloudShell 열기 → `ls -la /tmp/deploy2.py` 확인
2. 없으면 재생성 (deploy2.py base64 두 청크 echo → decode)
3. `python3 /tmp/deploy2.py` 실행
4. 배포 완료 후 브라우저에서 동작 확인

---

## 2026-06-19 (세션 1-2)

### 작업 내용
- Flask 2FA 인증 프록시 `app.py` 설계 및 작성 (365줄, 14914 bytes)
  - 로그인, TOTP 설정/검증, 관리자 페이지
  - 다크 테마 UI (Catppuccin Mocha)
  - 기본 관리자: admin / admin123
- nginx `auth_request` 연동 설정 작성
- systemd 서비스 파일 작성
- `deploy2.py` (boto3 SSM 배포 스크립트) 작성
  - nginx, systemd 내용 하드코딩
  - CloudShell `/tmp/app.py`를 읽어서 EC2로 배포
- CloudShell에 `/tmp/app.py` base64 청크 전송 완료
- 여러 CloudShell 탭 frozen 이슈 경험
  - 대안: 새 탭에서 재시도, 동일 컨테이너 공유 확인

### 확인된 사항
- EC2 인스턴스 i-0e81e9472e9f8a381 SSM 연결 가능
- CloudShell 컨테이너는 탭을 새로 열어도 /tmp 파일 공유됨
- get_page_text는 xterm.js 특성상 stale 상태 반환 많음
