#!/bin/bash
# scripts/install/01-check-environment.sh - 檢查環境

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "1" "檢查執行環境"

# 檢查 root 權限
if [ "$EUID" -ne 0 ]; then
    print_error "請使用 root 權限執行此腳本"
    exit 1
fi
print_success "root 權限檢查通過"

# 檢查必要指令
MISSING_CMDS=()
for cmd in gcc make wget tar sed awk grep; do
    if ! command -v $cmd >/dev/null 2>&1; then
        MISSING_CMDS+=($cmd)
    fi
done

if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
    print_warning "缺少必要指令: ${MISSING_CMDS[*]}"
    print_info "將在相依套件安裝步驟中補齊"
else
    print_success "必要指令檢查通過"
fi

# 檢查 PostgreSQL 是否可連線
if command -v psql &> /dev/null; then
    print_info "檢查 PostgreSQL 連線..."
    if PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d postgres -c "SELECT 1" >/dev/null 2>&1; then
        print_success "PostgreSQL 連線成功"
    else
        print_warning "無法連線到 PostgreSQL，後續步驟可能失敗"
        print_info "請確認 PostgreSQL 是否已啟動且認證資訊正確"
    fi
else
    print_warning "找不到 psql 指令，請確認 PostgreSQL 客戶端已安裝"
fi