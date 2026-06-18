# 문제 해결

## code-server가 열리지 않을 때

```bash
sudo systemctl status code-server@ubuntu
sudo systemctl restart code-server@ubuntu
sudo journalctl -u code-server@ubuntu -n 50
```

포트 확인:
```bash
ss -tlnp | grep 8080
```

## Lambda URL 접속 시 "Starting..." 화면이 계속 나올 때

1. EC2 인스턴스 ID가 올바른지 확인
   ```bash
   # Lambda 콘솔 → 환경 변수 탭에서 INSTANCE_ID 확인
   ```

2. Lambda IAM 역할에 EC2 권한이 있는지 확인
   ```bash
   aws iam list-attached-role-policies --role-name lambda-ec2-starter-role
   ```

3. EC2 Security Group에서 8080 포트가 열려 있는지 확인

4. EC2가 running 상태인지 확인
   ```bash
   aws ec2 describe-instances --instance-ids i-xxx --query 'Reservations[0].Instances[0].State'
   ```

## idle-shutdown이 작동하지 않을 때

```bash
# 서비스 상태
sudo systemctl status idle-shutdown

# 로그 확인
tail -f /var/log/idle-shutdown.log

# 수동 활성 상태 확인 (스크립트 직접 테스트)
who                                          # SSH 세션
ss -tn | awk '$4 ~ /:8080/ && $1=="ESTAB"'  # code-server 연결
ps aux | grep claude | grep -v grep         # Claude 프로세스
```

## Session Manager가 연결되지 않을 때

```bash
# SSM Agent 상태
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent

# 재시작
sudo snap restart amazon-ssm-agent

# EC2에 IAM 역할이 연결되어 있는지 확인
curl -s http://169.254.169.254/latest/meta-data/iam/info | python3 -m json.tool
```

## 비밀번호를 잊어버렸을 때

```bash
cat ~/.config/code-server/config.yaml
# 또는 변경
nano ~/.config/code-server/config.yaml
sudo systemctl restart code-server@ubuntu
```

## bootstrap.sh 재실행 (기존 리소스 업데이트)

```bash
bash infra/bootstrap.sh --instance-id i-xxx --region ap-northeast-2
```

이미 존재하는 리소스는 업데이트하고 새 리소스는 생성합니다. 멱등성이 보장됩니다.

## 새 EC2 인스턴스에 동일 환경 구축

1. 새 인스턴스 ID로 bootstrap.sh 재실행 (Lambda 환경 변수 업데이트)
2. 새 EC2에서 setup.sh 실행
3. Security Group 설정

```bash
# bootstrap.sh가 Lambda 환경변수를 새 인스턴스 ID로 자동 업데이트
bash infra/bootstrap.sh --instance-id i-NEW_INSTANCE_ID

# 새 EC2에서
sudo bash ec2/setup.sh
```
