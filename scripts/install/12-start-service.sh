#!/bin/bash
# scripts/install/09-start-service.sh - 啟動服務

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "12" "啟動 pgBouncer 服務"

# 啟用開機啟動
systemctl enable pgbouncer
print_success "已啟用開機啟動"

# 啟動服務
systemctl start pgbouncer

# 等待服務啟動
sleep 2

# 檢查服務狀態
if systemctl is-active --quiet pgbouncer; then
    print_success "pgBouncer 服務運行中"
else
    print_error "pgBouncer 啟動失敗"
    systemctl status pgbouncer --no-pager
    exit 1
fi

# 檢查監聽埠
if ss -tlnp | grep -q ":$PGBOUNCER_PORT"; then
    print_success "pgBouncer 監聽埠 $PGBOUNCER_PORT"
else
    print_warning "pgBouncer 未監聽埠 $PGBOUNCER_PORT"
fi