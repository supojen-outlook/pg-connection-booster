#!/bin/bash
# scripts/manage/list-roles.sh - 列出所有角色

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_header "pgBouncer 角色列表"

USERLIST_FILE="${PGBOUNCER_CONFIG_DIR}/userlist.txt"

if [ ! -f "$USERLIST_FILE" ]; then
    print_error "找不到 userlist.txt"
    exit 1
fi

echo -e "${CYAN}pgBouncer 中的角色:${NC}"
echo "  ════════════════════════════════════════════════"

# 讀取並顯示所有角色
TOTAL=0
while IFS= read -r line; do
    # 跳過註解和空行
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
        continue
    fi
    
    # 解析 "username" "password" 格式
    if [[ "$line" =~ ^\"([^\"]+)\"\ \"([^\"]+)\" ]]; then
        role="${BASH_REMATCH[1]}"
        echo "    • $role"
        TOTAL=$((TOTAL + 1))
    fi
done < "$USERLIST_FILE"

echo "  ════════════════════════════════════════════════"
echo -e "  總共: ${GREEN}$TOTAL${NC} 個角色"

# 如果可以連線到 PostgreSQL，也列出 PostgreSQL 中的相關角色
if command -v psql &> /dev/null; then
    echo ""
    echo -e "${CYAN}PostgreSQL 中的相關角色:${NC}"
    
    PGPASSWORD="$PG_SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPER_USER" -d postgres <<EOF 2>/dev/null | grep -E "($PGBOUNCER_ADMIN_ROLE|$APP_DB_OWNER|$CLIENT_ROLE)" || echo "   無法取得 PostgreSQL 角色資訊"
SELECT rolname FROM pg_roles WHERE rolname IN ('$PGBOUNCER_ADMIN_ROLE', '$APP_DB_OWNER', '$CLIENT_ROLE');
EOF
fi