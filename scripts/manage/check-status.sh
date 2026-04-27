#!/bin/bash
# scripts/manage/check-status.sh - 檢查 pgBouncer 狀態

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_header "pgBouncer 狀態檢查"

# 檢查服務狀態
echo -e "${YELLOW}1. 服務狀態:${NC}"
if systemctl is-active --quiet pgbouncer; then
    echo -e "   ${GREEN}✅ 運行中${NC}"
else
    echo -e "   ${RED}❌ 未運行${NC}"
fi
echo ""

# 檢查監聽埠
echo -e "${YELLOW}2. 監聽埠:${NC}"
if ss -tlnp | grep -q ":$PGBOUNCER_PORT"; then
    echo -e "   ${GREEN}✅ 埠 $PGBOUNCER_PORT 監聽中${NC}"
    ss -tlnp | grep ":$PGBOUNCER_PORT" | head -1 | sed 's/^/   /'
else
    echo -e "   ${RED}❌ 埠 $PGBOUNCER_PORT 未監聽${NC}"
fi
echo ""

# 檢查設定檔
echo -e "${YELLOW}3. 設定檔:${NC}"
if [ -f "$PGBOUNCER_CONFIG_DIR/pgbouncer.ini" ]; then
    echo -e "   ${GREEN}✅ pgbouncer.ini 存在${NC}"
    
    # 顯示重要設定
    echo -e "   重要設定:"
    grep -E "^(pool_mode|max_client_conn|default_pool_size)" "$PGBOUNCER_CONFIG_DIR/pgbouncer.ini" 2>/dev/null | sed 's/^/     /'
else
    echo -e "   ${RED}❌ pgbouncer.ini 不存在${NC}"
fi

if [ -f "$PGBOUNCER_CONFIG_DIR/userlist.txt" ]; then
    USER_COUNT=$(grep -c '^"' "$PGBOUNCER_CONFIG_DIR/userlist.txt" 2>/dev/null || echo 0)
    echo -e "   ${GREEN}✅ userlist.txt 存在 (使用者數: $USER_COUNT)${NC}"
else
    echo -e "   ${RED}❌ userlist.txt 不存在${NC}"
fi
echo ""

# 檢查連線數
echo -e "${YELLOW}4. 目前連線狀況:${NC}"
if command -v psql &> /dev/null && systemctl is-active --quiet pgbouncer; then
    # 嘗試連線到 pgbouncer 管理介面
    PGPASSWORD="$PGBOUNCER_ADMIN_PASSWORD" psql -h 127.0.0.1 -p "$PGBOUNCER_PORT" -U "$PGBOUNCER_ADMIN_ROLE" -d pgbouncer -c "SHOW POOLS;" 2>/dev/null | head -n 10 || echo "   無法取得連線資訊"
else
    echo "   psql 未安裝或 pgBouncer 未運行"
fi