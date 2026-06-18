#!/bin/bash
# ============================================================
# bootstrap.sh  — AWS 인프라 자동 구성
#
# 사용법:
#   bash bootstrap.sh \
#     --instance-id i-xxxxxxxxxxxxxxxxx \
#     --region ap-northeast-2
#
# 생성 항목:
#   - Lambda IAM 역할 + 정책
#   - Lambda 함수 (start-dev-server)
#   - Lambda 함수 URL (공개 엔드포인트)
#   - EC2 IAM 역할 (SSM + CloudWatch)
#
# 전제조건: AWS CLI 설치 및 적절한 권한 설정 필요
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

# ── 기본값 ──────────────────────────────────────────────────
INSTANCE_ID=""
REGION="ap-northeast-2"
CODE_SERVER_PORT="8080"
LAMBDA_FUNCTION_NAME="start-dev-server"
LAMBDA_ROLE_NAME="lambda-ec2-starter-role"
EC2_ROLE_NAME="ec2-dev-server-role"
EC2_INSTANCE_PROFILE_NAME="ec2-dev-server-profile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="$(dirname "$SCRIPT_DIR")/lambda"

# ── 인자 파싱 ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --instance-id)   INSTANCE_ID="$2";          shift 2 ;;
        --region)        REGION="$2";               shift 2 ;;
        --port)          CODE_SERVER_PORT="$2";      shift 2 ;;
        --function-name) LAMBDA_FUNCTION_NAME="$2"; shift 2 ;;
        *) warn "알 수 없는 인자: $1"; shift ;;
    esac
done

[[ -z "$INSTANCE_ID" ]] && error "--instance-id 인자가 필요합니다 (예: i-0123456789abcdef0)"
command -v aws &>/dev/null || error "AWS CLI가 설치되지 않았습니다"
command -v zip &>/dev/null || error "zip 명령이 필요합니다"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
info "AWS 계정: $AWS_ACCOUNT_ID | 리전: $REGION"

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║   Dev Server AWS 인프라 자동 구성        ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# ── 1. Lambda IAM 역할 ───────────────────────────────────────
header "1. Lambda IAM 역할 생성"

TRUST_POLICY='{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{"Service":"lambda.amazonaws.com"},
    "Action":"sts:AssumeRole"
  }]
}'

if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" &>/dev/null; then
    warn "역할 '$LAMBDA_ROLE_NAME' 이미 존재 — 건너뜀"
    LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
else
    LAMBDA_ROLE_ARN=$(aws iam create-role \
        --role-name "$LAMBDA_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Lambda role for starting/stopping dev EC2" \
        --query Role.Arn --output text)
    success "역할 생성: $LAMBDA_ROLE_ARN"
fi

# 기본 실행 정책
aws iam attach-role-policy \
    --role-name "$LAMBDA_ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
    2>/dev/null && success "AWSLambdaBasicExecutionRole 연결" || warn "이미 연결됨"

# EC2 시작/종료 정책 (인스턴스 ID로 한정)
EC2_POLICY="{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Sid\":\"StartStopTargetEC2\",
    \"Effect\":\"Allow\",
    \"Action\":[
      \"ec2:StartInstances\",
      \"ec2:StopInstances\",
      \"ec2:DescribeInstances\",
      \"ec2:DescribeInstanceStatus\"
    ],
    \"Resource\":\"arn:aws:ec2:${REGION}:${AWS_ACCOUNT_ID}:instance/${INSTANCE_ID}\"
  },{
    \"Sid\":\"DescribeAll\",
    \"Effect\":\"Allow\",
    \"Action\":[\"ec2:DescribeInstances\"],
    \"Resource\":\"*\"
  }]
}"

POLICY_NAME="lambda-ec2-starter-policy"
EXISTING_POLICY=$(aws iam list-policies \
    --scope Local \
    --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" \
    --output text 2>/dev/null)

if [[ -n "$EXISTING_POLICY" ]]; then
    warn "정책 '$POLICY_NAME' 이미 존재 — 버전 업데이트"
    # 기존 비기본 버전 삭제 (최대 5개 제한)
    OLD_VERSIONS=$(aws iam list-policy-versions \
        --policy-arn "$EXISTING_POLICY" \
        --query "Versions[?!IsDefaultVersion].VersionId" \
        --output text 2>/dev/null || true)
    for v in $OLD_VERSIONS; do
        aws iam delete-policy-version --policy-arn "$EXISTING_POLICY" --version-id "$v" 2>/dev/null || true
    done
    aws iam create-policy-version \
        --policy-arn "$EXISTING_POLICY" \
        --policy-document "$EC2_POLICY" \
        --set-as-default &>/dev/null
    EC2_POLICY_ARN="$EXISTING_POLICY"
else
    EC2_POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "$EC2_POLICY" \
        --description "Allow Lambda to start/stop specific EC2 dev server" \
        --query Policy.Arn --output text)
    success "정책 생성: $EC2_POLICY_ARN"
fi

aws iam attach-role-policy \
    --role-name "$LAMBDA_ROLE_NAME" \
    --policy-arn "$EC2_POLICY_ARN" \
    2>/dev/null && success "EC2 정책 연결" || warn "이미 연결됨"

# IAM 역할 전파 대기
info "IAM 역할 전파 대기 중 (10초)..."
sleep 10

# ── 2. Lambda 함수 패키징 ─────────────────────────────────────
header "2. Lambda 함수 패키징"

TMPDIR_ZIP=$(mktemp -d)
cp "$LAMBDA_DIR/lambda_function.py" "$TMPDIR_ZIP/"
cd "$TMPDIR_ZIP"
zip -q lambda_function.zip lambda_function.py
cd - &>/dev/null
success "lambda_function.zip 생성"

# ── 3. Lambda 함수 배포 ───────────────────────────────────────
header "3. Lambda 함수 배포"

EXISTING_FUNC=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" \
    --query FunctionArn --output text 2>/dev/null || true)

if [[ -n "$EXISTING_FUNC" ]]; then
    warn "함수 '$LAMBDA_FUNCTION_NAME' 이미 존재 — 코드 업데이트"
    aws lambda update-function-code \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$REGION" \
        --zip-file "fileb://$TMPDIR_ZIP/lambda_function.zip" \
        --query FunctionArn --output text &>/dev/null
    aws lambda update-function-configuration \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$REGION" \
        --environment "Variables={INSTANCE_ID=${INSTANCE_ID},REGION=${REGION},CODE_SERVER_PORT=${CODE_SERVER_PORT}}" \
        --timeout 15 \
        --query FunctionArn --output text &>/dev/null
    LAMBDA_ARN="$EXISTING_FUNC"
else
    LAMBDA_ARN=$(aws lambda create-function \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --runtime python3.12 \
        --role "$LAMBDA_ROLE_ARN" \
        --handler lambda_function.lambda_handler \
        --zip-file "fileb://$TMPDIR_ZIP/lambda_function.zip" \
        --region "$REGION" \
        --timeout 15 \
        --memory-size 128 \
        --environment "Variables={INSTANCE_ID=${INSTANCE_ID},REGION=${REGION},CODE_SERVER_PORT=${CODE_SERVER_PORT}}" \
        --description "Start dev EC2 and redirect to code-server" \
        --query FunctionArn --output text)
    success "Lambda 함수 생성: $LAMBDA_ARN"
fi

rm -rf "$TMPDIR_ZIP"

# Lambda 배포 완료 대기
aws lambda wait function-updated --function-name "$LAMBDA_FUNCTION_NAME" --region "$REGION" 2>/dev/null || true

# ── 4. Lambda 함수 URL 활성화 ─────────────────────────────────
header "4. Lambda 함수 URL (공개 엔드포인트)"

EXISTING_URL=$(aws lambda get-function-url-config \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" \
    --query FunctionUrl --output text 2>/dev/null || true)

if [[ -n "$EXISTING_URL" ]]; then
    FUNCTION_URL="$EXISTING_URL"
    warn "함수 URL 이미 존재"
else
    FUNCTION_URL=$(aws lambda create-function-url-config \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$REGION" \
        --auth-type NONE \
        --query FunctionUrl --output text)

    # 공개 접근 권한
    aws lambda add-permission \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$REGION" \
        --statement-id AllowPublicAccess \
        --action lambda:InvokeFunctionUrl \
        --principal "*" \
        --function-url-auth-type NONE &>/dev/null
    success "함수 URL 생성"
fi

# ── 5. EC2 IAM 역할 (Session Manager) ────────────────────────
header "5. EC2 IAM 역할 (Session Manager + CloudWatch)"

EC2_TRUST='{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{"Service":"ec2.amazonaws.com"},
    "Action":"sts:AssumeRole"
  }]
}'

if aws iam get-role --role-name "$EC2_ROLE_NAME" &>/dev/null; then
    warn "EC2 역할 '$EC2_ROLE_NAME' 이미 존재"
else
    aws iam create-role \
        --role-name "$EC2_ROLE_NAME" \
        --assume-role-policy-document "$EC2_TRUST" \
        --description "Dev EC2 role for SSM and CloudWatch" \
        --query Role.Arn --output text &>/dev/null
    success "EC2 역할 생성"
fi

for POLICY_ARN in \
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" \
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"; do
    aws iam attach-role-policy \
        --role-name "$EC2_ROLE_NAME" \
        --policy-arn "$POLICY_ARN" \
        2>/dev/null && success "연결: $(basename $POLICY_ARN)" || warn "이미 연결됨: $(basename $POLICY_ARN)"
done

# 인스턴스 프로파일
if aws iam get-instance-profile --instance-profile-name "$EC2_INSTANCE_PROFILE_NAME" &>/dev/null; then
    warn "인스턴스 프로파일 이미 존재"
else
    aws iam create-instance-profile \
        --instance-profile-name "$EC2_INSTANCE_PROFILE_NAME" &>/dev/null
    aws iam add-role-to-instance-profile \
        --instance-profile-name "$EC2_INSTANCE_PROFILE_NAME" \
        --role-name "$EC2_ROLE_NAME"
    success "인스턴스 프로파일 생성"
fi

# ── 6. EC2에 IAM 프로파일 연결 ───────────────────────────────
header "6. EC2 인스턴스에 IAM 프로파일 연결"

CURRENT_PROFILE=$(aws ec2 describe-iam-instance-profile-associations \
    --filters "Name=instance-id,Values=${INSTANCE_ID}" \
    --query "IamInstanceProfileAssociations[0].AssociationId" \
    --output text --region "$REGION" 2>/dev/null || true)

if [[ "$CURRENT_PROFILE" == "None" || -z "$CURRENT_PROFILE" ]]; then
    aws ec2 associate-iam-instance-profile \
        --instance-id "$INSTANCE_ID" \
        --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
        --region "$REGION" &>/dev/null
    success "EC2에 IAM 프로파일 연결 완료"
else
    warn "EC2 IAM 프로파일 이미 연결됨 (AssociationId: $CURRENT_PROFILE)"
fi

# ── 완료 ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   AWS 인프라 구성 완료!                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  인스턴스 ID  : %-44s║\n" "$INSTANCE_ID"
printf "║  Lambda URL   : %-44s║\n" "${FUNCTION_URL:0:44}"
if [[ ${#FUNCTION_URL} -gt 44 ]]; then
printf "║               %-46s║\n" "${FUNCTION_URL:44}"
fi
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  다음 단계:                                                  ║"
echo "║  1. 위 Lambda URL을 핸드폰 홈 화면에 북마크                 ║"
echo "║  2. EC2 Security Group에서 포트 8080 오픈                   ║"
echo "║  3. EC2에서 ec2/setup.sh 실행                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# 결과를 파일로도 저장
cat > "$(dirname "$SCRIPT_DIR")/.bootstrap-result.env" <<EOF
INSTANCE_ID=${INSTANCE_ID}
REGION=${REGION}
LAMBDA_FUNCTION_NAME=${LAMBDA_FUNCTION_NAME}
LAMBDA_URL=${FUNCTION_URL}
EC2_ROLE_NAME=${EC2_ROLE_NAME}
CODE_SERVER_PORT=${CODE_SERVER_PORT}
EOF
info "구성 결과 저장: .bootstrap-result.env"
