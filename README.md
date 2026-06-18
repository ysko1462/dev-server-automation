# dev-server-automation

AWS EC2 개발 서버 자동화 — Lambda 원클릭 기동 + code-server + 30분 유휴 자동 종료

핸드폰 포함 어디서든 접속해서 Claude Code로 바이브코딩할 수 있는 환경을 구축합니다.

## 아키텍처

```
[브라우저/핸드폰] → [Lambda URL 북마크]
                         │
              stopped ───┤─ EC2 start + "Starting..." HTML (15s 자동 새로고침)
              pending ───┤─ "Starting..." HTML
              running ───┘─ 302 redirect → http://<EC2-IP>:8080 (code-server)
                                                    │
                                         [EC2: code-server + Claude Code]
                                                    │ 30분 유휴
                                                    ▼
                                              shutdown -h now
```

## 접속 방법

| 방법 | 용도 |
|------|------|
| Lambda URL → code-server | 브라우저 개발 (핸드폰 포함) |
| SSH | 터미널 직접 접속 |
| AWS Session Manager | 키페어 없는 웹 콘솔 |

## 빠른 시작

### 1단계: AWS 인프라 자동 구성

```bash
git clone https://github.com/jwko76/dev-server-automation.git
cd dev-server-automation

bash infra/bootstrap.sh \
  --instance-id i-xxxxxxxxxxxxxxxxx \
  --region ap-northeast-2
```

완료 후 출력되는 **Lambda URL**을 핸드폰 홈 화면에 북마크합니다.

### 2단계: EC2 초기 설정

EC2에 SSH 또는 Session Manager로 접속 후:

```bash
curl -fsSL https://raw.githubusercontent.com/jwko76/dev-server-automation/main/ec2/setup.sh \
  | sudo bash
```

또는 옵션 지정:

```bash
sudo bash ec2/setup.sh \
  --port 8080 \
  --password "MySecurePassword123" \
  --idle-limit 1800 \
  --workspace /home/ubuntu/workspace
```

### 3단계: Security Group 설정

| 포트 | 용도 |
|------|------|
| 22 | SSH |
| 8080 | code-server |

## 파일 구조

```
dev-server-automation/
├── ec2/
│   ├── setup.sh              # EC2 원클릭 초기 설정
│   ├── idle-shutdown.sh      # 유휴 감지 자동 종료
│   └── idle-shutdown.service # systemd 서비스
├── lambda/
│   └── lambda_function.py    # EC2 기동 + code-server 리다이렉트
├── infra/
│   ├── bootstrap.sh          # AWS 인프라 자동 구성 (IAM, Lambda, 함수URL)
│   ├── lambda-iam-policy.json
│   └── ec2-ssm-policy.json
├── tests/
│   ├── test_lambda.py        # Lambda 단위 테스트 (mock boto3)
│   └── test_idle_shutdown.sh # idle-shutdown 로직 테스트
└── docs/
    ├── setup-guide.md        # 단계별 상세 설정 가이드
    └── troubleshooting.md    # 문제 해결
```

## 유휴 감지 기준

아래 중 하나라도 해당되면 타이머 리셋:

- SSH 세션 존재
- code-server WebSocket 연결 존재 (포트 8080)
- `claude` 프로세스 CPU > 5%
- 워크스페이스 파일 변경 감지 (`.git` 제외)

30분 연속 비활성 → 30초 유예 후 `shutdown -h now`

## 테스트 실행

```bash
# Lambda 단위 테스트 (boto3 필요)
pip install boto3
python3 tests/test_lambda.py

# idle-shutdown 로직 테스트
bash tests/test_idle_shutdown.sh
```

## 비용 (ap-northeast-2 기준)

- EC2 t3.micro: $0.0116/시간
- Lambda, API Gateway: 월 100만 건 무료 범위 내 무료
- 하루 4시간 사용 시 약 **$1.4/월**

## 환경 변수 커스터마이징

`/etc/idle-shutdown.env` (setup.sh가 자동 생성):

```bash
IDLE_LIMIT=1800        # 유휴 종료 시간 (초)
CHECK_INTERVAL=60      # 상태 확인 주기 (초)
CPU_THRESHOLD=5        # Claude CPU 임계값 (%)
CODE_SERVER_PORT=8080
WORKSPACE=/home/ubuntu/workspace
```
