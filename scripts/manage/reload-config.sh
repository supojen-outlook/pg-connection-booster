#!/bin/bash
# scripts/manage/reload-config.sh - 重新載入設定檔

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_header "重新載入 pgBouncer 設定"

if ! systemctl is-active --quiet pgbouncer; then
    print_error "pgBouncer 未執行"
    exit 1
fi

# 檢查設定檔語法
print_info "檢查設定檔語法..."
if sudo -u pgbouncer "$PGBOUNCER_PREFIX/bin/pgbouncer" -u "$PGBOUNCER_CONFIG_DIR/pgbouncer.ini" > /dev/null 2>&1; then
    print_success "設定檔語法正確"
else
    print_error "設定檔有錯誤"
    exit 1
fi

# 重新載入
systemctl reload pgbouncer
print_success "已重新載入 pgBouncer 設定"

# 顯示狀態
echo ""
systemctl status pgbouncer --no-pager -l | head -n 5