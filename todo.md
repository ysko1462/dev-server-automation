# TODO

## 남은 정리 작업

### 1. admin 비밀번호 변경 (보안 필수)
현재 기본값 `admin123` 사용 중. 반드시 변경 필요.

EC2에서 직접 실행하거나 deploy 스크립트 통해 실행:
```bash
# /opt/auth-server/users.json 직접 수정
# 또는 /auth/admin 페이지 → 사용자 관리에서 변경
# http://54.174.199.241:8080/auth/admin
```

### 2. EC2 Phase 1 잔여 파일 삭제
```bash
rm -f /var/www/setup/qr.png
```

### 3. HTTPS 적용 (선택사항 — 도메인 있을 때)
도메인을 EC2 IP에 연결한 후:
```bash
# certbot 설치
sudo apt install certbot python3-certbot-nginx -y

# 인증서 발급 (도메인 예: dev.example.com)
sudo certbot --nginx -d dev.example.com

# nginx 포트를 80/443으로 변경 후 reload
```

---

## 완료된 항목

- [x] Flask 2FA 인증 프록시 `app.py` 설계 및 작성 (365줄)
- [x] nginx `auth_request` 연동 설정 작성
- [x] systemd 서비스 파일 작성
- [x] `deploy2.py` (SSM 배포 스크립트) 작성
- [x] EC2 배포 완료: app.py, nginx, systemd 서비스 모두 적용
- [x] `http://54.174.199.241:8080` 커스텀 로그인 페이지 응답 (200 OK)
- [x] WebSocket 1006 에러 수정 완료
- [x] 전체 2FA 플로우 브라우저 검증 완료 (로그인 → TOTP → code-server 접속)
- [x] GitHub push 완료 (`ysko1462/dev-server-automation`)

---

## 디버그 참고 명령

```bash
# 서비스 상태
systemctl status auth-server
systemctl status code-server@ubuntu
systemctl status nginx

# 로그
journalctl -u auth-server -n 50
journalctl -u code-server@ubuntu -n 50
tail -30 /var/log/nginx/access.log
tail -30 /var/log/nginx/error.log

# 포트 확인
ss -tlnp | grep -E '8080|8081|8090'

# Flask 인증 테스트
curl -s http://127.0.0.1:8090/auth/check

# nginx 설정 테스트
nginx -t
```
