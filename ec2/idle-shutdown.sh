#!/bin/bash
# idle-shutdown.sh  v1.2
# EC2 idle detection & auto shutdown
# Conditions checked (any active -> reset timer):
#   1. SSH sessions
#   2. code-server browser connections (ESTABLISHED on CODE_SERVER_PORT)
#   3. claude process CPU > CPU_THRESHOLD%
#   4. Workspace file modified after IDLE_FILE timestamp

set -euo pipefail

IDLE_LIMIT="${IDLE_LIMIT:-1800}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
CPU_THRESHOLD="${CPU_THRESHOLD:-5}"
CODE_SERVER_PORT="${CODE_SERVER_PORT:-8080}"
WORKSPACE="${WORKSPACE:-$HOME/workspace}"
IDLE_FILE="/tmp/.dev_server_last_activity"
LOG_FILE="/var/log/idle-shutdown.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

is_active() {
    # 1. SSH sessions
    local ssh_count
    ssh_count=$(who 2>/dev/null | grep -vc "^$" || true)
    if [[ "$ssh_count" -gt 0 ]]; then
        log "ACTIVE: SSH sessions=${ssh_count}"
        return 0
    fi

    # 2. code-server WebSocket connections
    local cs_conn
    cs_conn=$(ss -tn 2>/dev/null \
              | awk -v port=":${CODE_SERVER_PORT}" '$4 ~ port && $1=="ESTAB"' \
              | wc -l || true)
    if [[ "$cs_conn" -gt 0 ]]; then
        log "ACTIVE: code-server connections=${cs_conn}"
        return 0
    fi

    # 3. Claude Code CPU
    local claude_cpu
    claude_cpu=$(ps aux 2>/dev/null \
                 | grep -E 'claude|node.*claude' \
                 | grep -v grep \
                 | awk '{s+=$3} END{print s+0}')
    if awk "BEGIN{exit !($claude_cpu > $CPU_THRESHOLD)}" 2>/dev/null; then
        log "ACTIVE: Claude CPU=${claude_cpu}%"
        return 0
    fi

    # 4. Workspace file changes (exclude .git)
    if [[ -d "$WORKSPACE" ]]; then
        local recent
        recent=$(find "$WORKSPACE" -mindepth 1 -newer "$IDLE_FILE" \
                      -not -path '*/.git' \
                      -not -path '*/.git/*' \
                      -not -name '*.log' \
                      -maxdepth 5 2>/dev/null | head -1)
        if [[ -n "$recent" ]]; then
            log "ACTIVE: file changed (${recent##*/})"
            return 0
        fi
    fi

    return 1
}

log "idle-shutdown started (limit=${IDLE_LIMIT}s, interval=${CHECK_INTERVAL}s)"
touch "$IDLE_FILE"

while true; do
    if is_active; then
        touch "$IDLE_FILE"
    fi

    local_last=$(stat -c %Y "$IDLE_FILE" 2>/dev/null || date +%s)
    now=$(date +%s)
    idle=$(( now - local_last ))

    if [[ "$idle" -gt "$IDLE_LIMIT" ]]; then
        log "Idle ${idle}s exceeded limit. Grace period 30s..."
        sleep 30
        if is_active; then
            log "Shutdown cancelled: activity detected during grace period"
            touch "$IDLE_FILE"
        else
            log "Shutting down EC2 (idle=${idle}s)"
            sudo shutdown -h now "idle-shutdown: idle ${idle}s"
        fi
    else
        remaining=$(( IDLE_LIMIT - idle ))
        log "Idle ${idle}s / remaining ${remaining}s"
    fi

    sleep "$CHECK_INTERVAL"
done
