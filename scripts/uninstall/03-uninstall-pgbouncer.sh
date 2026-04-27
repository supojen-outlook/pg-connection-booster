#!/bin/bash
# scripts/uninstall/03-uninstall-pgbouncer.sh - 卸載 pgBouncer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "3" "卸載 pgBouncer"

# 刪除 systemd service
if [ -f "/etc/systemd/system/pgbouncer.service" ]; then
    rm -f "/etc/systemd/system/pgbouncer.service"
    systemctl daemon-reload
    print_success "已刪除 systemd service"
fi

# 如果不保留安裝目錄，則刪除
if [ "$KEEP_CONFIG" != "true" ]; then
    if [ -d "$PGBOUNCER_PREFIX" ]; then
        rm -rf "$PGBOUNCER_PREFIX"
        print_success "已刪除安裝目錄: $PGBOUNCER_PREFIX"
    fi
else
    print_info "保留安裝目錄 (KEEP_CONFIG=true)"
fi

# 刪除原始碼
if [ -d "$PGBOUNCER_SOURCE_DIR/pgbouncer-${PGBOUNCER_VERSION}" ]; then
    rm -rf "$PGBOUNCER_SOURCE_DIR/pgbouncer-${PGBOUNCER_VERSION}"
    print_success "已刪除原始碼目錄"
fi

if [ -f "$PGBOUNCER_SOURCE_DIR/pgbouncer-${PGBOUNCER_VERSION}.tar.gz" ]; then
    rm -f "$PGBOUNCER_SOURCE_DIR/pgbouncer-${PGBOUNCER_VERSION}.tar.gz"
    print_success "已刪除原始碼壓縮檔"
fi