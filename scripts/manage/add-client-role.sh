#!/bin/bash
# scripts/manage/add-client-role.sh - 新增客戶端角色

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_header "新增客戶端角色"

if [ $# -lt 3 ]; then
    print_error "使用方式: $0 <db_name> <role_name> <password> [owner]"
    echo "  範例: $0 myapp_db new_user user_password db_owner"
    exit 1
fi

DB_NAME="$1"
ROLE_NAME="$2"
ROLE_PASSWORD="$3"
DB_OWNER="${4:-$APP_DB_OWNER}"

print_info "資料庫: $DB_NAME"
print_info "角色名稱: $ROLE_NAME"

# 建立暫時的 .pgpass
PGPASS_FILE="/tmp/.pgpass.$$"
cat > "$PGPASS_FILE" <<EOF
${PG_HOST}:${PG_PORT}:postgres:${PG_SUPER_USER}:${PG_SUPER_PASSWORD}
EOF
chmod 600 "$PGPASS_FILE"
export PGPASSFILE="$PGPASS_FILE"

# 建立角色
PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d postgres <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$ROLE_NAME') THEN
        CREATE ROLE $ROLE_NAME WITH LOGIN PASSWORD '$ROLE_PASSWORD';
        RAISE NOTICE '✅ 角色 % 建立完成', '$ROLE_NAME';
    ELSE
        RAISE NOTICE 'ℹ️ 角色 % 已存在', '$ROLE_NAME';
    END IF;
END
\$\$;

GRANT CONNECT ON DATABASE $DB_NAME TO $ROLE_NAME;
EOF

# 授予 schema 權限
PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d "$DB_NAME" <<EOF
GRANT USAGE ON SCHEMA public TO $ROLE_NAME;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $ROLE_NAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $ROLE_NAME;
EOF

# 加入 pgBouncer userlist
if [ -f "${PGBOUNCER_CONFIG_DIR}/userlist.txt" ]; then
    echo "\"$ROLE_NAME\" \"$ROLE_PASSWORD\"" >> "${PGBOUNCER_CONFIG_DIR}/userlist.txt"
    print_success "已加入 pgBouncer userlist.txt"
    
    # 重新載入 pgBouncer
    systemctl reload pgbouncer 2>/dev/null || true
fi

rm -f "$PGPASS_FILE"
unset PGPASSFILE

print_success "角色 $ROLE_NAME 新增完成"