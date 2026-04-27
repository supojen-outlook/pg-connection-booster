#!/bin/bash
# scripts/manage/remove-client-role.sh - 移除客戶端角色

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_header "移除客戶端角色"

if [ $# -lt 1 ]; then
    print_error "使用方式: $0 <role_name>"
    echo "  範例: $0 myapp_user"
    exit 1
fi

ROLE_NAME="$1"

print_info "角色名稱: $ROLE_NAME"

# 從 pgBouncer userlist 中移除
if [ -f "${PGBOUNCER_CONFIG_DIR}/userlist.txt" ]; then
    if grep -q "^\"$ROLE_NAME\"" "${PGBOUNCER_CONFIG_DIR}/userlist.txt"; then
        # 備份
        cp "${PGBOUNCER_CONFIG_DIR}/userlist.txt" "${PGBOUNCER_CONFIG_DIR}/userlist.txt.bak"
        
        # 移除該行
        sed -i "/^\"$ROLE_NAME\"/d" "${PGBOUNCER_CONFIG_DIR}/userlist.txt"
        print_success "已從 pgBouncer userlist.txt 移除 $ROLE_NAME"
        
        # 重新載入 pgBouncer
        systemctl reload pgbouncer 2>/dev/null || true
    else
        print_warning "角色 $ROLE_NAME 不在 pgBouncer userlist.txt 中"
    fi
fi

# 詢問是否也要從 PostgreSQL 移除
print_warning "是否需要也從 PostgreSQL 移除角色 $ROLE_NAME？(y/N)"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 建立暫時的 .pgpass
    PGPASS_FILE="/tmp/.pgpass.$$"
    cat > "$PGPASS_FILE" <<EOF
${PG_HOST}:${PG_PORT}:postgres:${PG_SUPER_USER}:${PG_SUPER_PASSWORD}
EOF
    chmod 600 "$PGPASS_FILE"
    export PGPASSFILE="$PGPASS_FILE"
    
    # 從 PostgreSQL 移除角色
    PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d postgres <<EOF
REVOKE ALL PRIVILEGES ON DATABASE $APP_DB_NAME FROM $ROLE_NAME;
DROP ROLE IF EXISTS $ROLE_NAME;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "已從 PostgreSQL 移除角色 $ROLE_NAME"
    else
        print_error "從 PostgreSQL 移除角色失敗"
    fi
    
    rm -f "$PGPASS_FILE"
    unset PGPASSFILE
fi

print_success "角色 $ROLE_NAME 移除完成"