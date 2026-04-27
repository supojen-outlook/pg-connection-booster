#!/bin/bash
# scripts/uninstall/02-remove-config.sh - 移除配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "2" "移除配置檔案"

# 備份配置（除非跳過）
if [ "$SKIP_BACKUP" != "true" ]; then
    BACKUP_DIR="/tmp/pgbouncer-config-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
        cp -r "$PGBOUNCER_CONFIG_DIR" "$BACKUP_DIR/"
        print_success "配置已備份到: $BACKUP_DIR"
    fi
    
    if [ -d "$PGBOUNCER_LOG_DIR" ]; then
        cp -r "$PGBOUNCER_LOG_DIR" "$BACKUP_DIR/logs" 2>/dev/null || true
    fi
fi

# 如果不保留配置，則刪除
if [ "$KEEP_CONFIG" != "true" ]; then
    if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
        rm -rf "$PGBOUNCER_CONFIG_DIR"
        print_success "已刪除設定目錄: $PGBOUNCER_CONFIG_DIR"
    fi
else
    print_info "保留配置檔案 (KEEP_CONFIG=true)"
fi