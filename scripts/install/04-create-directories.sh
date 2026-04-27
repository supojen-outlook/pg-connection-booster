#!/bin/bash
# scripts/install/04-create-directories.sh - 建立目錄結構

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "4" "建立目錄結構"

# 安裝目錄
if [ ! -d "$PGBOUNCER_PREFIX" ]; then
    mkdir -p "$PGBOUNCER_PREFIX"/{bin,lib,share}
    print_success "建立安裝目錄: $PGBOUNCER_PREFIX"
fi

# 設定目錄
if [ ! -d "$PGBOUNCER_CONFIG_DIR" ]; then
    mkdir -p "$PGBOUNCER_CONFIG_DIR"
    print_success "建立設定目錄: $PGBOUNCER_CONFIG_DIR"
fi

# 日誌目錄
if [ ! -d "$PGBOUNCER_LOG_DIR" ]; then
    mkdir -p "$PGBOUNCER_LOG_DIR"
    print_success "建立日誌目錄: $PGBOUNCER_LOG_DIR"
fi

# 運行目錄
if [ ! -d "$PGBOUNCER_RUN_DIR" ]; then
    mkdir -p "$PGBOUNCER_RUN_DIR"
    print_success "建立運行目錄: $PGBOUNCER_RUN_DIR"
fi

# 原始碼目錄
if [ ! -d "$PGBOUNCER_SOURCE_DIR" ]; then
    mkdir -p "$PGBOUNCER_SOURCE_DIR"
    print_success "建立原始碼目錄: $PGBOUNCER_SOURCE_DIR"
fi

# 設定權限
chown -R pgbouncer:pgbouncer "$PGBOUNCER_CONFIG_DIR" "$PGBOUNCER_LOG_DIR" "$PGBOUNCER_RUN_DIR" 2>/dev/null || true
chmod 750 "$PGBOUNCER_CONFIG_DIR"
chmod 750 "$PGBOUNCER_LOG_DIR"
chmod 755 "$PGBOUNCER_RUN_DIR"

print_success "目錄權限設定完成"