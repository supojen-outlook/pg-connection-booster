#!/bin/bash
# scripts/uninstall/01-stop-service.sh - 停止服務

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "1" "停止 pgBouncer 服務"

if systemctl is-active --quiet pgbouncer; then
    systemctl stop pgbouncer
    systemctl disable pgbouncer
    print_success "pgBouncer 已停止並取消開機啟動"
else
    print_warning "pgBouncer 未在運行"
fi