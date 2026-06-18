# TODO

## 긴급 (다음 세션에서 바로 해야 할 일)

- [ ] **deploy2.py 실행 확인 및 재시도**
  - CloudShell에서 `ls -la /tmp/deploy2.py` 확인
  - 없으면 base64 청크 2개 echo → decode → 실행
  - 있으면 `python3 /tmp/deploy2.py` 바로 실행
  - PART1 (chars 1-3000): `IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMw...U3RhbmRhcmRPdXRwdXRDb250ZW50J`
  - PART2 (chars 3001-end): `LCcnKS5zdHJpcCgp...YWRtaW4xMjMnKQo=`
  - 전체 base64는 `outputs/deploy2.py`를 `base64 | tr -d '\n'`으로 재생성 가능

- [ ] **배포 완료 후 동작 검증**
  - `http://54.174.199.241:8080` → 커스텀 로그인 페이지 표시 확인 (HTTP Basic Auth 팝업 X)
  - `admin` / `admin123` 로그인 → QR 코드 페이지 표시 확인
  - Google Authenticator로 QR 스캔 → TOTP 입력 → code-server 접근 확인
  - `/auth/admin` 페이지에서 사용자 추가/삭제 기능 확인

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
- [ ] `/tmp/deploy2.py` decode 및 syntax check (명령 전송했으나 확인 미완)
