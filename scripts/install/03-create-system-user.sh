#!/bin/bash
# scripts/install/03-create-system-user.sh - 建立系統用戶

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "3" "建立 pgbouncer 系統用戶和組"

# 建立組
if getent group pgbouncer > /dev/null 2>&1; then
    EXISTING_GID=$(getent group pgbouncer | cut -d: -f3)
    print_warning "pgbouncer 組已存在 (GID: $EXISTING_GID)"
    
    if [ "$EXISTING_GID" != "$PGBOUNCER_GROUP_GID" ]; then
        print_warning "  期望 GID: $PGBOUNCER_GROUP_GID, 實際 GID: $EXISTING_GID"
    fi
else
    groupadd --gid "$PGBOUNCER_GROUP_GID" --system pgbouncer
    print_success "pgbouncer 組建立完成 (GID: $PGBOUNCER_GROUP_GID)"
fi

# 建立用戶
if id "pgbouncer" > /dev/null 2>&1; then
    EXISTING_UID=$(id -u pgbouncer)
    print_warning "pgbouncer 用戶已存在 (UID: $EXISTING_UID)"
    
    if [ "$EXISTING_UID" != "$PGBOUNCER_USER_UID" ]; then
        print_warning "  期望 UID: $PGBOUNCER_USER_UID, 實際 UID: $EXISTING_UID"
    fi
else
    useradd \
        --uid "$PGBOUNCER_USER_UID" \
        --gid pgbouncer \
        --shell /sbin/nologin \
        --system \
        --no-create-home \
        --home-dir /nonexistent \
        --comment "pgBouncer Connection Pooler" \
        pgbouncer
    
    print_success "pgbouncer 用戶建立完成 (UID: $PGBOUNCER_USER_UID)"
fi


# 顯示用戶資訊
echo -e "\n$(print_color "CYAN" "用戶資訊:")"
echo "  UID: $(id -u pgbouncer)"
echo "  GID: $(id -g pgbouncer)"
echo "  登入 Shell: $(getent passwd pgbouncer | cut -d: -f7)"