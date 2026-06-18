# 작업 로그

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
