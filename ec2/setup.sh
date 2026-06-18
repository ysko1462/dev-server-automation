#!/bin/bash
# ============================================================
# setup.sh  — EC2 개발 서버 원클릭 초기 설정
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/jwko76/dev-server-automation/main/ec2/setup.sh | bash
#   또는
#   bash setup.sh [--port PORT] [--password PW] [--idle-limit SECONDS] [--workspace DIR]
#
# 설치 항목:
#   - code-server (브라우저 VS Code)
#   - idle-shutdown 서비스 (유휴 자동 종료)
#   - AWS SSM Agent (웹 콘솔 연결)
#   - claude code
# ============================================================

set -euo pipefail

# ── 색상 ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

# ── 기본값 ──────────────────────────────────────────────────
CODE_SERVER_PORT=8080
CODE_SERVER_PASSWORD=""
IDLE_LIMIT=1800                     # 30분
WORKSPACE="$HOME/workspace"
GITHUB_RAW="https://raw.githubusercontent.com/jwko76/dev-server-automation/main"
INSTALL_CLAUDE=true
SKIP_CODE_SERVER=false

# ── 인자 파싱 ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)       CODE_SERVER_PORT="$2";     shift 2 ;;
        --password)   CODE_SERVER_PASSWORD="$2"; shift 2 ;;
        --idle-limit) IDLE_LIMIT="$2";           shift 2 ;;
        --workspace)  WORKSPACE="$2";            shift 2 ;;
        --skip-claude)       INSTALL_CLAUDE=false;       shift ;;
        --skip-code-server)  SKIP_CODE_SERVER=true;      shift ;;
        *) warn "알 수 없는 인자: $1"; shift ;;
    esac
done

# ── 루트 권한 확인 ────────────────────────────────────────────
[[ "$(id -u)" -ne 0 ]] && error "root 또는 sudo로 실행해 주세요: sudo bash setup.sh"

ACTUAL_USER="${SUDO_USER:-ubuntu}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
WORKSPACE="${WORKSPACE/#\~/$ACTUAL_HOME}"
WORKSPACE="${WORKSPACE/#\$HOME/$ACTUAL_HOME}"

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║   Dev Server Auto Setup                  ║"
echo "║   code-server + idle-shutdown + SSM      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# ── 1. 시스템 업데이트 ────────────────────────────────────────
header "1. 시스템 패키지 업데이트"
apt-get update -q
apt-get install -y -q curl wget git unzip jq bc
success "기본 패키지 설치 완료"

# ── 2. code-server 설치 ───────────────────────────────────────
header "2. code-server 설치"
if $SKIP_CODE_SERVER && command -v code-server &>/dev/null; then
    warn "code-server 이미 설치됨 — 건너뜀"
else
    info "code-server 최신 버전 설치 중..."
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone 2>&1 | tail -5

    # 설정 디렉토리
    CS_CONFIG_DIR="$ACTUAL_HOME/.config/code-server"
    mkdir -p "$CS_CONFIG_DIR"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CS_CONFIG_DIR"

    # 비밀번호 설정
    if [[ -z "$CODE_SERVER_PASSWORD" ]]; then
        CODE_SERVER_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
        warn "비밀번호가 없어 자동 생성됩니다: ${BOLD}${CODE_SERVER_PASSWORD}${RESET}"
    fi

    cat > "$CS_CONFIG_DIR/config.yaml" <<EOF
bind-addr: 0.0.0.0:${CODE_SERVER_PORT}
auth: password
password: ${CODE_SERVER_PASSWORD}
cert: false
EOF
    chown "$ACTUAL_USER:$ACTUAL_USER" "$CS_CONFIG_DIR/config.yaml"

    # systemd 서비스 활성화
    systemctl enable --now "code-server@${ACTUAL_USER}" || true
    success "code-server 설치 완료 (포트: ${CODE_SERVER_PORT})"
fi

# ── 3. 워크스페이스 생성 ──────────────────────────────────────
header "3. 워크스페이스 디렉토리"
mkdir -p "$WORKSPACE"
chown "$ACTUAL_USER:$ACTUAL_USER" "$WORKSPACE"
success "워크스페이스: $WORKSPACE"

# ── 4. idle-shutdown 설치 ─────────────────────────────────────
header "4. 유휴 자동 종료 설치"

# 환경변수 파일
cat > /etc/idle-shutdown.env <<EOF
IDLE_LIMIT=${IDLE_LIMIT}
CHECK_INTERVAL=60
CPU_THRESHOLD=5
CODE_SERVER_PORT=${CODE_SERVER_PORT}
WORKSPACE=${WORKSPACE}
EOF

# 스크립트 다운로드
info "idle-shutdown.sh 다운로드 중..."
curl -fsSL "${GITHUB_RAW}/ec2/idle-shutdown.sh" -o /usr/local/bin/idle-shutdown.sh
chmod +x /usr/local/bin/idle-shutdown.sh

# sudoers (shutdown 권한)
echo "${ACTUAL_USER} ALL=(ALL) NOPASSWD: /sbin/shutdown" \
    > /etc/sudoers.d/idle-shutdown
chmod 440 /etc/sudoers.d/idle-shutdown

# systemd 서비스
curl -fsSL "${GITHUB_RAW}/ec2/idle-shutdown.service" \
    -o /etc/systemd/system/idle-shutdown.service
systemctl daemon-reload
systemctl enable --now idle-shutdown
success "idle-shutdown 서비스 활성화 완료"

# ── 5. AWS SSM Agent ──────────────────────────────────────────
header "5. AWS SSM Agent"
if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent 2>/dev/null; then
    success "SSM Agent 이미 실행 중"
elif snap list amazon-ssm-agent &>/dev/null; then
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent
    success "SSM Agent 시작 완료"
else
    info "SSM Agent 설치 중..."
    snap install amazon-ssm-agent --classic 2>/dev/null || true
    snap start amazon-ssm-agent 2>/dev/null || true
    success "SSM Agent 설치 완료"
fi

# ── 6. Claude Code 설치 ───────────────────────────────────────
header "6. Claude Code 설치"
if $INSTALL_CLAUDE; then
    if command -v claude &>/dev/null; then
        success "Claude Code 이미 설치됨"
    else
        info "Node.js 설치 확인..."
        if ! command -v node &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - &>/dev/null
            apt-get install -y -q nodejs
        fi
        info "Claude Code 설치 중..."
        npm install -g @anthropic-ai/claude-code 2>&1 | tail -3
        success "Claude Code 설치 완료"
    fi
else
    warn "Claude Code 설치 건너뜀 (--skip-claude)"
fi

# ── 완료 요약 ─────────────────────────────────────────────────
PUBLIC_IP=$(curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "확인 필요")

echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║              설치 완료!                          ║"
echo "╠══════════════════════════════════════════════════╣"
printf "║  code-server  : http://%-26s║\n" "${PUBLIC_IP}:${CODE_SERVER_PORT}"
if [[ -n "$CODE_SERVER_PASSWORD" ]]; then
printf "║  비밀번호     : %-34s║\n" "$CODE_SERVER_PASSWORD"
fi
printf "║  워크스페이스 : %-34s║\n" "$WORKSPACE"
printf "║  유휴 종료    : %-34s║\n" "${IDLE_LIMIT}초 ($(( IDLE_LIMIT / 60 ))분)"
echo "╠══════════════════════════════════════════════════╣"
echo "║  다음 단계:                                      ║"
echo "║  1. EC2에 EC2 IAM 역할(SSM) 연결                ║"
echo "║  2. Security Group: 8080 포트 오픈              ║"
echo "║  3. Lambda 함수 배포 (infra/bootstrap.sh)       ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${RESET}"
