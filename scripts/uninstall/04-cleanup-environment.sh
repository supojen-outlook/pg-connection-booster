#!/bin/bash
# scripts/uninstall/04-cleanup-environment.sh - 清理環境

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "4" "清理環境"

# 刪除日誌目錄（如果不保留數據）
if [ "$KEEP_DATA" != "true" ]; then
    if [ -d "$PGBOUNCER_LOG_DIR" ]; then
        rm -rf "$PGBOUNCER_LOG_DIR"
        print_success "已刪除日誌目錄: $PGBOUNCER_LOG_DIR"
    fi
    
    if [ -d "$PGBOUNCER_RUN_DIR" ]; then
        rm -rf "$PGBOUNCER_RUN_DIR"
        print_success "已刪除運行目錄: $PGBOUNCER_RUN_DIR"
    fi
else
    print_info "保留數據目錄 (KEEP_DATA=true)"
fi

# 刪除 pgbouncer 用戶（如果不保留系統配置）
if [ "$KEEP_SYSTEM_CONFIG" != "true" ]; then
    if id "pgbouncer" > /dev/null 2>&1; then
        # 檢查是否有程序在運行
        if pgrep -u pgbouncer > /dev/null 2>&1; then
            print_warning "pgbouncer 用戶還有程序在運行，跳過刪除"
        else
            userdel pgbouncer
            print_success "已刪除 pgbouncer 用戶"
        fi
    fi
    
    if getent group pgbouncer > /dev/null 2>&1; then
        groupdel pgbouncer
        print_success "已刪除 pgbouncer 組"
    fi
else
    print_info "保留系統用戶和組 (KEEP_SYSTEM_CONFIG=true)"
fi