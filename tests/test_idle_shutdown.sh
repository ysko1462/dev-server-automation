#!/bin/bash
# test_idle_shutdown.sh — idle-shutdown.sh logic tests (no AWS needed)

set -uo pipefail

PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET} $1"; PASS=$(( PASS + 1 )); }
fail() { echo -e "${RED}FAIL${RESET} $1"; FAIL=$(( FAIL + 1 )); }
section() { echo -e "\n${BOLD}-- $1 --${RESET}"; }

SCRIPT="$(cd "$(dirname "$0")" && pwd)/../ec2/idle-shutdown.sh"
[[ -f "$SCRIPT" ]] || { echo "idle-shutdown.sh not found: $SCRIPT"; exit 1; }

# Test environment
IDLE_FILE=$(mktemp)
LOG_FILE="/dev/null"
CODE_SERVER_PORT=19999
WORKSPACE=$(mktemp -d)
CPU_THRESHOLD=5

# Inline is_active logic (mirrors idle-shutdown.sh but uses mock variables)
is_active_test() {
    local ssh_count="${MOCK_SSH:-0}"
    if [[ "$ssh_count" -gt 0 ]]; then return 0; fi

    local cs_conn="${MOCK_CS_CONN:-0}"
    if [[ "$cs_conn" -gt 0 ]]; then return 0; fi

    local claude_cpu="${MOCK_CLAUDE_CPU:-0}"
    if awk "BEGIN{exit !($claude_cpu > $CPU_THRESHOLD)}" 2>/dev/null; then return 0; fi

    if [[ -d "$WORKSPACE" ]]; then
        local recent
        recent=$(find "$WORKSPACE" -mindepth 1 -newer "$IDLE_FILE" \
                      -not -path '*/.git' \
                      -not -path '*/.git/*' \
                      -not -name '*.log' \
                      -maxdepth 5 2>/dev/null | head -1)
        if [[ -n "$recent" ]]; then return 0; fi
    fi
    return 1
}

# ── 1. All idle ───────────────────────────────────────────────
section "1. All conditions idle"
MOCK_SSH=0 MOCK_CS_CONN=0 MOCK_CLAUDE_CPU=0
if ! is_active_test; then pass "all idle -> inactive"; else fail "all idle -> wrongly active"; fi

# ── 2. SSH session ────────────────────────────────────────────
section "2. SSH session detection"
MOCK_SSH=1 MOCK_CS_CONN=0 MOCK_CLAUDE_CPU=0
if is_active_test; then pass "SSH=1 -> active"; else fail "SSH=1 -> wrongly idle"; fi
MOCK_SSH=0

# ── 3. code-server connection ─────────────────────────────────
section "3. code-server connection detection"
MOCK_SSH=0 MOCK_CS_CONN=2 MOCK_CLAUDE_CPU=0
if is_active_test; then pass "CS_CONN=2 -> active"; else fail "CS_CONN=2 -> wrongly idle"; fi
MOCK_CS_CONN=0

# ── 4. Claude CPU threshold ───────────────────────────────────
section "4. Claude CPU threshold (${CPU_THRESHOLD}%)"
MOCK_CLAUDE_CPU=1
if ! is_active_test; then pass "CPU=1% < ${CPU_THRESHOLD}% -> idle"; else fail "CPU=1% wrongly active"; fi

MOCK_CLAUDE_CPU=10
if is_active_test; then pass "CPU=10% > ${CPU_THRESHOLD}% -> active"; else fail "CPU=10% wrongly idle"; fi

MOCK_CLAUDE_CPU=5
if ! is_active_test; then pass "CPU=5% == threshold -> idle (strict >)"; else fail "CPU=5% boundary error"; fi
MOCK_CLAUDE_CPU=0

# ── 5. Workspace file change ──────────────────────────────────
section "5. Workspace file change detection"
MOCK_SSH=0 MOCK_CS_CONN=0 MOCK_CLAUDE_CPU=0
touch -t 202001010000 "$IDLE_FILE"
echo "test" > "$WORKSPACE/test_file.py"

if is_active_test; then pass "new file -> active"; else fail "new file not detected"; fi

rm "$WORKSPACE/test_file.py"
touch "$IDLE_FILE"
sleep 0.1
if ! is_active_test; then pass "no new file -> idle"; else fail "no file wrongly active"; fi

# ── 6. .git exclusion ────────────────────────────────────────
section "6. .git directory exclusion"
touch -t 202001010000 "$IDLE_FILE"
mkdir -p "$WORKSPACE/.git"
echo "commit" > "$WORKSPACE/.git/COMMIT_EDITMSG"

if ! is_active_test; then
    pass ".git files ignored -> idle"
else
    fail ".git file wrongly detected as change"
fi

rm -rf "$WORKSPACE/.git"
touch "$IDLE_FILE"

# ── 7. Idle timer logic ───────────────────────────────────────
section "7. Idle timer calculation"
LIMIT_TEST=5

touch "$IDLE_FILE"
sleep 0.1
idle_now=$(( $(date +%s) - $(stat -c %Y "$IDLE_FILE") ))
if [[ "$idle_now" -le "$LIMIT_TEST" ]]; then
    pass "idle=${idle_now}s <= ${LIMIT_TEST}s -> no shutdown"
else
    fail "idle time calculation error"
fi

# Set IDLE_FILE 10s in the past
python3 -c "import os, time; os.utime('$IDLE_FILE', (time.time()-10, time.time()-10))" 2>/dev/null \
    || touch -d "10 seconds ago" "$IDLE_FILE" 2>/dev/null \
    || true

idle_now=$(( $(date +%s) - $(stat -c %Y "$IDLE_FILE") ))
if [[ "$idle_now" -gt "$LIMIT_TEST" ]]; then
    pass "idle=${idle_now}s > ${LIMIT_TEST}s -> shutdown condition met"
else
    fail "idle time not past threshold (idle=${idle_now}s)"
fi

# ── 8. Script syntax checks ───────────────────────────────────
section "8. Bash syntax checks"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for f in ec2/idle-shutdown.sh ec2/setup.sh infra/bootstrap.sh; do
    if bash -n "$REPO_ROOT/$f" 2>/dev/null; then
        pass "$f: no syntax errors"
    else
        fail "$f: syntax error"
        bash -n "$REPO_ROOT/$f"
    fi
done

# ── Cleanup ───────────────────────────────────────────────────
rm -f "$IDLE_FILE"
rm -rf "$WORKSPACE"

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== Test Results ===${RESET}"
TOTAL=$(( PASS + FAIL ))
echo "Total: ${TOTAL} | PASS: ${PASS} | FAIL: ${FAIL}"

if [[ "$FAIL" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}${FAIL} test(s) failed${RESET}"
    exit 1
fi
