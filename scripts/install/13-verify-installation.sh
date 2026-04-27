#!/bin/bash
# scripts/install/12-verify-installation.sh - 驗證安裝

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "13" "驗證安裝結果"

ERRORS=0

# 檢查服務狀態
if systemctl is-active --quiet pgbouncer; then
    print_success "pgBouncer 服務運行中"
else
    print_error "pgBouncer 服務未運行"
    ERRORS=$((ERRORS+1))
fi

# 檢查監聽埠
if ss -tlnp | grep -q ":$PGBOUNCER_PORT"; then
    print_success "監聽埠 $PGBOUNCER_PORT"
else
    print_warning "未監聽埠 $PGBOUNCER_PORT"
fi

# 檢查設定檔
if [ -f "$PGBOUNCER_CONFIG_DIR/pgbouncer.ini" ]; then
    print_success "設定檔存在: pgbouncer.ini"
else
    print_error "設定檔不存在: pgbouncer.ini"
    ERRORS=$((ERRORS+1))
fi

if [ -f "$PGBOUNCER_CONFIG_DIR/userlist.txt" ]; then
    print_success "設定檔存在: userlist.txt"
else
    print_error "設定檔不存在: userlist.txt"
    ERRORS=$((ERRORS+1))
fi

# 檢查 PostgreSQL 角色
if command -v psql &> /dev/null; then
    print_info "檢查 PostgreSQL 角色..."
    
    PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d postgres -t -c "SELECT 1 FROM pg_roles WHERE rolname='$PGBOUNCER_ADMIN_ROLE'" | grep -q 1
    if [ $? -eq 0 ]; then
        print_success "pgBouncer 管理角色 $PGBOUNCER_ADMIN_ROLE 存在"
    else
        print_warning "pgBouncer 管理角色 $PGBOUNCER_ADMIN_ROLE 不存在"
    fi
    
    PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$APP_DB_NAME'" | grep -q 1
    if [ $? -eq 0 ]; then
        print_success "應用程式資料庫 $APP_DB_NAME 存在"
    else
        print_warning "應用程式資料庫 $APP_DB_NAME 不存在"
    fi
fi

# 檢查目錄權限
DIR_PERMS=$(stat -c '%a' "$PGBOUNCER_CONFIG_DIR" 2>/dev/null || stat -f '%A' "$PGBOUNCER_CONFIG_DIR" 2>/dev/null)
if [ "$DIR_PERMS" = "750" ]; then
    print_success "設定目錄權限正確"
else
    print_warning "設定目錄權限應為 750，目前為 $DIR_PERMS"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    print_success "所有檢查通過！"
else
    print_warning "有 $ERRORS 個檢查項目失敗"
fi