# TODO

## 완료된 항목

- [x] Flask 2FA 인증 프록시 `app.py` 설계 및 작성 (365줄)
- [x] nginx `auth_request` 연동 설정 작성
- [x] systemd 서비스 파일 작성
- [x] `deploy2.py` (SSM 배포 스크립트) 작성
- [x] CloudShell에 `/tmp/app.py` 전송 완료 (syntax valid, 365줄 확인)
- [x] `deploy2.py` 로컬(Desktop Commander + boto3)에서 실행 완료
- [x] EC2 배포 완료: app.py, nginx, systemd 서비스 모두 적용
- [x] `http://54.174.199.241:8080` → 커스텀 로그인 페이지 응답 확인 (200 OK)
- [x] WebSocket 1006 에러 수정 완료
  - 원인: code-server v4.123.0 host check (Host 헤더에 포트 필요)
  - 수정: nginx `proxy_set_header Host 127.0.0.1:8081` + `Origin http://127.0.0.1:8081`
- [x] **전체 2FA 플로우 브라우저 검증 완료** ✅
  - 로그인 → TOTP → code-server 정상 접속

## 남은 정리 작업

- [ ] EC2의 Phase 1 아티팩트 삭제: `rm -f /var/www/setup/qr.png`
- [ ] admin 비밀번호 변경 (`admin123` → 강력한 비밀번호)
- [ ] HTTPS 적용 (Let's Encrypt + 도메인, 선택사항)
