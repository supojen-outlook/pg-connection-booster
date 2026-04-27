#!/bin/bash
# scripts/install/05-download-source.sh - 下載原始碼

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "5" "下載 pgBouncer $PGBOUNCER_VERSION 原始碼"

SOURCE_FILE="${PGBOUNCER_SOURCE_DIR}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz"

# 檢查是否已下載
if [ -f "$SOURCE_FILE" ]; then
    print_warning "原始碼已存在: $SOURCE_FILE"
    
    FILE_SIZE=$(stat -c%s "$SOURCE_FILE" 2>/dev/null || stat -f%z "$SOURCE_FILE" 2>/dev/null)
    if [ $FILE_SIZE -lt 100000 ]; then
        print_warning "原始碼檔案可能不完整，重新下載"
        rm -f "$SOURCE_FILE"
    else
        print_success "使用現有原始碼"
        exit 0
    fi
fi

print_info "下載中: $PGBOUNCER_SOURCE_URL"
wget -O "$SOURCE_FILE" "$PGBOUNCER_SOURCE_URL" --progress=bar:force 2>&1

if [ -f "$SOURCE_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$SOURCE_FILE" 2>/dev/null || stat -f%z "$SOURCE_FILE" 2>/dev/null)
    print_success "下載完成 (大小: $((FILE_SIZE/1024))KB)"
else
    print_error "下載失敗"
    exit 1
fi