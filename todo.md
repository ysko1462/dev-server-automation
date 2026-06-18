# TODO

## 남은 작업

- [ ] **실제 브라우저에서 최종 검증**
  - `http://54.174.199.241:8080` 접속 → 로그인 페이지 확인
  - `admin` / `admin123` 로그인 → QR 코드 페이지 확인
  - Google Authenticator로 QR 스캔 → TOTP 6자리 입력 → code-server 접근
  - `/auth/admin` 페이지에서 사용자 추가/삭제/2FA 리셋 기능 확인

## 완료 후 정리 작업

- [ ] EC2의 Phase 1 아티팩트 삭제: `rm -f /var/www/setup/qr.png`
- [ ] 기존 nginx 기본 설정 충돌 여부 확인

## 배포 실패 시 디버그 순서

1. `systemctl status auth-server` → 서비스 상태 확인
2. `journalctl -u auth-server -n 50` → 로그 확인
3. `nginx -t` → nginx 설정 문법 확인
4. `ss -tlnp | grep -E '8080|8081|8090'` → 포트 리스닝 확인
5. `curl -s http://127.0.0.1:8090/auth/check` → Flask 응답 확인

## 완료된 항목

- [x] Flask 2FA 인증 프록시 `app.py` 설계 및 작성 (365줄)
- [x] nginx `auth_request` 연동 설정 작성
- [x] systemd 서비스 파일 작성
- [x] `deploy2.py` (SSM 배포 스크립트) 작성
- [x] CloudShell에 `/tmp/app.py` 전송 완료 (syntax valid, 365줄 확인)
- [x] CloudShell에 `/tmp/d2.b64` PART1 echo 완료
- [x] `deploy2.py` 로컬(Desktop Commander + boto3)에서 실행 완료
- [x] EC2 배포 완료: app.py, nginx, systemd 서비스 모두 적용
- [x] `http://54.174.199.241:8080` → 커스텀 로그인 페이지 응답 확인 (200 OK)
