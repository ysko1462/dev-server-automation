# 작업 로그

---

## 2026-06-19 (세션 6) — WebSocket 1006 에러 수정 완료 ✅

### 문제 분석 과정
1. nginx access log에서 WebSocket 경로(`/stable-77.../reconnectionToken=...`) → **403** 발견
2. Flask `/auth/check`는 정상적으로 200 반환 중 (인증 문제 아님)
3. 403이 code-server 자체에서 반환됨 확인
4. code-server v4.123.0의 **host check** 메커니즘이 원인
   - WebSocket 요청의 `Host` 헤더를 `bind-addr`(`127.0.0.1:8081`)와 정확히 비교
   - nginx가 `Host: 54.174.199.241:8080`을 포워딩 → 불일치 → 403
5. `Host: 127.0.0.1` (포트 없음)으로 변경해도 여전히 403
   - code-server는 포트 포함 `127.0.0.1:8081`을 기대
6. `Host: 127.0.0.1:8081` (포트 포함)으로 변경 → 404 (host check 통과, 토큰만 invalid)

### 최종 수정 내용 (nginx)
```nginx
location / {
    auth_request /auth/check;
    error_page 401 = @do_login;
    proxy_pass http://127.0.0.1:8081;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host 127.0.0.1:8081;          # ← 포트 포함 필수
    proxy_set_header Origin http://127.0.0.1:8081;  # ← Origin도 override
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 86400;
}
```

### 현재 상태
| 항목 | 상태 |
|------|------|
| EC2 Flask 인증 프록시 | ✅ 8090 포트, active |
| nginx (8080) | ✅ 외부 접근 가능 |
| code-server (8081) | ✅ 내부 실행 중, auth: none |
| 로그인 → TOTP → code-server | ✅ **정상 동작 확인** |
| WebSocket 1006 에러 | ✅ **수정 완료** |

### 다음 세션에서 할 일
1. admin 비밀번호 변경 (admin123 → 강력한 비밀번호)
2. EC2 Phase 1 아티팩트 정리: `rm -f /var/www/setup/qr.png`
3. (선택) HTTPS 적용 — 도메인 있으면 Let's Encrypt

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

---

## 2026-06-19 (세션 4)

### 작업 내용
- Desktop Commander 플러그인 설치 후 연결 확인
- `claude.md`, `todo.md`, `worklog.md` → `dev-server-automation/` 폴더에 복사
- `git config --global core.longpaths true` (Windows MAX_PATH 우회)
- `git init` + `git add . && git commit` 성공 (16 files, root-commit 6c64b38)
- GitHub username 확인: `ysko1462`
- Python 스크립트로 GitHub API 호출 → `ysko1462/dev-server-automation` repo 생성
- `git push -u origin main` 성공

---

## 2026-06-19 (세션 1-3)

### 작업 내용
- Flask 2FA 인증 프록시 `app.py` 설계 및 작성 (365줄, 14914 bytes)
- nginx `auth_request` 연동 설정 작성
- systemd 서비스 파일 작성
- `deploy2.py` (boto3 SSM 배포 스크립트) 작성
- CloudShell에 `/tmp/app.py` base64 청크 전송 완료
