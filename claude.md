# 프로젝트 개요: code-server 2FA 인증 프록시

## 목표
AWS EC2 t3.micro (Ubuntu)에서 실행 중인 code-server(브라우저 VS Code)에
Flask 기반 2FA 인증 프록시를 배포한다.

## 인증 흐름
1. 사용자가 `http://54.174.199.241:8080` 접속
2. ID+PW 입력 (1차 인증)
3. 최초 로그인 시 → Google Authenticator QR 코드 등록 페이지
4. 이후 로그인 시 → Google Authenticator TOTP 6자리 입력 (2차 인증)
5. 인증 완료 후 code-server 접근

## 관리자 기능
- `/auth/admin` 페이지에서 사용자 추가/삭제, 2FA 리셋
- 기본 관리자 계정: `admin` / `admin123`

## 인프라 구성
| 항목 | 값 |
|------|-----|
| EC2 인스턴스 ID | i-0e81e9472e9f8a381 |
| 퍼블릭 IP | 54.174.199.241 |
| 리전 | us-east-1 |
| OS | Ubuntu (t3.micro) |
| code-server | 127.0.0.1:8081 (내부) |
| nginx | 포트 8080 (외부 진입점) |
| Flask 인증 프록시 | 127.0.0.1:8090 (내부) |

## 파일 구성
| 파일 | 위치 | 설명 |
|------|------|------|
| app.py | `/opt/auth-server/app.py` (EC2) | Flask 인증 프록시 (365줄) |
| nginx 설정 | `/etc/nginx/sites-available/code-server` (EC2) | auth_request 연동 |
| systemd 서비스 | `/etc/systemd/system/auth-server.service` (EC2) | auth-server 서비스 |
| deploy2.py | CloudShell `/tmp/deploy2.py` | SSM 배포 스크립트 |
| app.py (소스) | CloudShell `/tmp/app.py` | 배포용 소스 (365줄, 14914 bytes) |

## 배포 방법
CloudShell에서 `python3 /tmp/deploy2.py` 실행
- boto3로 SSM send-command를 사용해 EC2에 원격 배포
- app.py를 base64 청크로 전송 → nginx 설정 → systemd 서비스 등록 → 시작

## 주요 파일 내용 (workspace)
- `outputs/app.py`: Flask 앱 소스
- `outputs/deploy2.py`: 배포 스크립트 (nginx/service 하드코딩, /tmp/app.py 읽음)

## CloudShell 작업 팁
- get_page_text가 stale한 경우가 많음 → type 명령으로 보내고 결과 대기
- 탭이 frozen되면 새 탭 생성 후 재사용 (동일 컨테이너 세션 유지)
- 긴 파일 전송: base64 인코딩 → echo 2~3개 청크 → base64 -d 디코드
- CloudShell 탭 관리: 667779425, 667779428, 667779431, 667779434 (일부 frozen)
