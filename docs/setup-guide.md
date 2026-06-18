# 단계별 상세 설정 가이드

## 전제조건

- AWS CLI 설치 및 설정 (`aws configure`)
- EC2 t3.micro (Ubuntu 22.04 LTS) 실행 중
- EC2 인스턴스 ID 확인 (`i-xxxxxxxxxxxxxxxxx`)
- `Name=dev-server` 태그 설정 (선택 — bootstrap.sh는 인스턴스 ID 직접 사용)

## 1. AWS 인프라 구성 (bootstrap.sh)

```bash
bash infra/bootstrap.sh \
  --instance-id i-xxxxxxxxxxxxxxxxx \
  --region ap-northeast-2 \
  --port 8080
```

생성되는 리소스:

| 리소스 | 이름 |
|--------|------|
| Lambda IAM 역할 | `lambda-ec2-starter-role` |
| Lambda IAM 정책 | `lambda-ec2-starter-policy` |
| Lambda 함수 | `start-dev-server` |
| Lambda 함수 URL | 자동 생성 (공개) |
| EC2 IAM 역할 | `ec2-dev-server-role` |
| EC2 인스턴스 프로파일 | `ec2-dev-server-profile` |

완료 후 `.bootstrap-result.env` 파일에 Lambda URL 등 결과가 저장됩니다.

### Lambda 함수 URL을 북마크로 저장

```
https://xxxx.lambda-url.ap-northeast-2.on.aws/
```

이 URL을 **핸드폰 홈 화면**에 북마크하면 탭 한 번으로 서버 기동 + code-server 접속이 됩니다.

## 2. EC2 초기 설정 (setup.sh)

EC2에 SSH 또는 Session Manager로 접속 후 실행:

```bash
# GitHub에서 직접 실행 (원클릭)
curl -fsSL https://raw.githubusercontent.com/jwko76/dev-server-automation/main/ec2/setup.sh \
  | sudo bash

# 또는 로컬 파일로
sudo bash ec2/setup.sh --password "StrongPassword123"
```

설치 항목:
- code-server (최신 버전, standalone 설치)
- idle-shutdown 서비스
- AWS SSM Agent
- Claude Code (Node.js 포함)

### 설정 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--port` | 8080 | code-server 포트 |
| `--password` | 자동생성 | code-server 비밀번호 |
| `--idle-limit` | 1800 | 유휴 종료 시간 (초) |
| `--workspace` | ~/workspace | 워크스페이스 경로 |
| `--skip-claude` | false | Claude Code 설치 건너뜀 |
| `--skip-code-server` | false | code-server 설치 건너뜀 |

## 3. Security Group 설정

AWS 콘솔 → EC2 → 보안 그룹 → 인바운드 규칙:

| 포트 | 프로토콜 | 소스 | 용도 |
|------|---------|------|------|
| 22 | TCP | 내 IP | SSH |
| 8080 | TCP | 0.0.0.0/0 | code-server |

> 보안 강화: code-server 비밀번호 인증으로 공개 포트도 안전합니다.
> Elastic IP를 사용하면 IP 변경 없이 고정 URL로 접속 가능합니다.

## 4. Elastic IP (권장)

재시작마다 IP가 바뀌지 않도록 고정 IP 설정:

```
EC2 → 탄력적 IP → 탄력적 IP 주소 할당 → 인스턴스 연결
```

Lambda URL은 IP와 무관하게 동작하지만, Elastic IP를 쓰면 code-server URL도 고정됩니다.

> 비용: EC2 실행 중에는 무료, 중지 상태에서만 $0.005/시간 과금

## 5. 사용 흐름

```
1. 핸드폰에서 북마크한 Lambda URL 탭
   → 서버 꺼져 있으면: "Starting..." 화면 (15초 자동 새로고침)
   → 약 1~2분 후 code-server 화면으로 자동 이동

2. code-server 비밀번호 입력 후 개발 시작

3. Claude Code로 바이브코딩

4. 작업 완료 후 그냥 브라우저 닫기
   → 30분 후 idle-shutdown이 자동으로 EC2 종료
```

## 6. 서비스 관리

```bash
# idle-shutdown 상태 확인
sudo systemctl status idle-shutdown

# 실시간 로그
sudo journalctl -fu idle-shutdown

# 임시 비활성화 (유지보수 시)
sudo systemctl stop idle-shutdown

# 유휴 시간 변경 (예: 1시간)
sudo nano /etc/idle-shutdown.env
# IDLE_LIMIT=3600
sudo systemctl restart idle-shutdown

# code-server 재시작
sudo systemctl restart code-server@ubuntu
```
