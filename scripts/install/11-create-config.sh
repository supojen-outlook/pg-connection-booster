#!/bin/bash
# scripts/install/07-create-config.sh - 建立 pgBouncer 設定檔
# ============================================================================
# 功能說明：
#   1. 從 PostgreSQL 取得已建立角色的 SCRAM-SHA-256 hash 值
#   2. 根據模板產生 pgbouncer.ini 設定檔
#   3. 產生 userlist.txt 認證檔（使用正確的 hash 值，不含註解）
# 
# 重要提醒：
#   - 此腳本必須在 10-create-pgbouncer-role.sh 和 11-create-app-database.sh 之後執行
#   - 因為需要角色已經存在於 PostgreSQL 中才能取得 hash
#   - userlist.txt 不可包含註解，否則 pgBouncer 會回報 "broken auth file" 錯誤
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "11" "建立 pgBouncer 設定檔"

CONFIG_DIR="$PGBOUNCER_CONFIG_DIR"
TEMPLATE_DIR="${PROJECT_DIR}/config"

# 備份現有設定檔（如果存在）
if [ -f "$CONFIG_DIR/pgbouncer.ini" ]; then
    backup_file "$CONFIG_DIR/pgbouncer.ini"
fi

if [ -f "$CONFIG_DIR/userlist.txt" ]; then
    backup_file "$CONFIG_DIR/userlist.txt"
fi

# ============================================================================
# 從 PostgreSQL 取得角色的 SCRAM hash
# ============================================================================
print_info "從 PostgreSQL 取得角色的密碼 hash..."

# 偵測連線方式（與 10、11 腳本相同的邏輯）
# 優先順序：
#   1. sudo -u postgres（本機 Unix socket，最常見）
#   2. TCP + 密碼（遠端連線）
#   3. 一般使用者的 psql（備用方案）
if sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
    PSQL_CMD="sudo -u postgres psql"
    print_success "使用 sudo -u postgres 連線取得 hash"
elif [ -n "$PG_SUPER_PASSWORD" ]; then
    export PGPASSWORD="$PG_SUPER_PASSWORD"
    PSQL_CMD="psql -h ${PG_HOST:-localhost} -p $PG_PORT -U $PG_SUPER_USER -d postgres"
    print_success "使用 TCP 連線取得 hash"
else
    PSQL_CMD="psql -U postgres -d postgres"
    print_success "使用 Unix socket 連線取得 hash"
fi

# ----------------------------------------------------------------------------
# 取得 pgbouncer 管理角色的 hash
# ----------------------------------------------------------------------------
print_info "查詢角色 $PGBOUNCER_ADMIN_ROLE 的密碼 hash..."
PGBOUNCER_HASH=$($PSQL_CMD -t -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$PGBOUNCER_ADMIN_ROLE';" | head -1 | xargs)

if [ -z "$PGBOUNCER_HASH" ] || [ "$PGBOUNCER_HASH" = "" ]; then
    print_error "找不到 $PGBOUNCER_ADMIN_ROLE 的 hash，請確認角色是否已建立"
    print_info "可用以下指令手動查詢所有角色："
    echo "  sudo -u postgres psql -c \"SELECT rolname, rolpassword FROM pg_authid;\""
    print_info "如果角色尚未建立，請先執行："
    echo "  ./scripts/install/10-create-pgbouncer-role.sh"
    exit 1
else
    print_success "取得 $PGBOUNCER_ADMIN_ROLE 的 hash"
    echo "  hash: ${PGBOUNCER_HASH:0:50}..."
fi

# ----------------------------------------------------------------------------
# 取得 client 角色的 hash
# ----------------------------------------------------------------------------
print_info "查詢角色 $CLIENT_ROLE 的密碼 hash..."
CLIENT_HASH=$($PSQL_CMD -t -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$CLIENT_ROLE';" | head -1 | xargs)

if [ -z "$CLIENT_HASH" ] || [ "$CLIENT_HASH" = "" ]; then
    print_error "找不到 $CLIENT_ROLE 的 hash，請確認角色是否已建立"
    print_info "可用以下指令手動查詢所有角色："
    echo "  sudo -u postgres psql -c \"SELECT rolname, rolpassword FROM pg_authid;\""
    print_info "如果角色尚未建立，請先執行："
    echo "  ./scripts/install/11-create-app-database.sh"
    exit 1
else
    print_success "取得 $CLIENT_ROLE 的 hash"
    echo "  hash: ${CLIENT_HASH:0:50}..."
fi

# 清除密碼環境變數（避免影響後續步驟）
unset PGPASSWORD

# ============================================================================
# 產生 pgbouncer.ini 設定檔
# ============================================================================
print_info "產生 pgbouncer.ini"

# 檢查 SSL 憑證是否存在，如果存在則啟用 SSL
SSL_ENABLED="false"
if [ -f "/etc/pgbouncer/ssl/server.crt" ] && [ -f "/etc/pgbouncer/ssl/server.key" ]; then
    print_info "偵測到 SSL 憑證，將啟用 SSL 設定"
    SSL_ENABLED="true"
    
    # 產生啟用 SSL 的設定檔
    sed -e "s|{{PG_HOST}}|$PG_HOST|g" \
        -e "s|{{PG_PORT}}|$PG_PORT|g" \
        -e "s|{{APP_DB_NAME}}|$APP_DB_NAME|g" \
        -e "s|{{PGBOUNCER_LISTEN_ADDR}}|$PGBOUNCER_LISTEN_ADDR|g" \
        -e "s|{{PGBOUNCER_PORT}}|$PGBOUNCER_PORT|g" \
        -e "s|{{PGBOUNCER_RUN_DIR}}|$PGBOUNCER_RUN_DIR|g" \
        -e "s|{{PGBOUNCER_CONFIG_DIR}}|$PGBOUNCER_CONFIG_DIR|g" \
        -e "s|{{PGBOUNCER_LOG_DIR}}|$PGBOUNCER_LOG_DIR|g" \
        -e "s|{{PGBOUNCER_POOL_MODE}}|$PGBOUNCER_POOL_MODE|g" \
        -e "s|{{PGBOUNCER_MAX_CLIENT_CONN}}|$PGBOUNCER_MAX_CLIENT_CONN|g" \
        -e "s|{{PGBOUNCER_DEFAULT_POOL_SIZE}}|$PGBOUNCER_DEFAULT_POOL_SIZE|g" \
        -e "s|{{PGBOUNCER_MIN_POOL_SIZE}}|$PGBOUNCER_MIN_POOL_SIZE|g" \
        -e "s|{{PGBOUNCER_RESERVE_POOL_SIZE}}|$PGBOUNCER_RESERVE_POOL_SIZE|g" \
        -e "s|{{PGBOUNCER_RESERVE_POOL_TIMEOUT}}|$PGBOUNCER_RESERVE_POOL_TIMEOUT|g" \
        -e "s|{{PGBOUNCER_ADMIN_ROLE}}|$PGBOUNCER_ADMIN_ROLE|g" \
        "$TEMPLATE_DIR/pgbouncer.ini.template" | \
    # 先移除 SSL 設定的註解符號，然後替換變數
    sed 's|^# client_tls_sslmode = {{CLIENT_TLS_SSLMODE}}|client_tls_sslmode = {{CLIENT_TLS_SSLMODE}}|' | \
    sed 's|^# client_tls_cert_file = {{SSL_CERT_PATH}}|client_tls_cert_file = {{SSL_CERT_PATH}}|' | \
    sed 's|^# client_tls_key_file = {{SSL_KEY_PATH}}|client_tls_key_file = {{SSL_KEY_PATH}}|' | \
    sed 's|^# server_tls_sslmode = {{SERVER_TLS_SSLMODE}}|server_tls_sslmode = {{SERVER_TLS_SSLMODE}}|' | \
    # 然後替換 SSL 相關變數
    sed -e "s|{{CLIENT_TLS_SSLMODE}}|${CLIENT_TLS_SSLMODE:-require}|g" \
        -e "s|{{SERVER_TLS_SSLMODE}}|${SERVER_TLS_SSLMODE:-disable}|g" \
        -e "s|{{SSL_CERT_PATH}}|/etc/pgbouncer/ssl/server.crt|g" \
        -e "s|{{SSL_KEY_PATH}}|/etc/pgbouncer/ssl/server.key|g" \
        > "$CONFIG_DIR/pgbouncer.ini"
    
    print_success "SSL 設定已啟用"
else
    print_warning "未偵測到 SSL 憑證，將停用 SSL 設定"
    
    # 產生不啟用 SSL 的設定檔
    sed -e "s|{{PG_HOST}}|$PG_HOST|g" \
        -e "s|{{PG_PORT}}|$PG_PORT|g" \
        -e "s|{{APP_DB_NAME}}|$APP_DB_NAME|g" \
        -e "s|{{PGBOUNCER_LISTEN_ADDR}}|$PGBOUNCER_LISTEN_ADDR|g" \
        -e "s|{{PGBOUNCER_PORT}}|$PGBOUNCER_PORT|g" \
        -e "s|{{PGBOUNCER_RUN_DIR}}|$PGBOUNCER_RUN_DIR|g" \
        -e "s|{{PGBOUNCER_CONFIG_DIR}}|$PGBOUNCER_CONFIG_DIR|g" \
        -e "s|{{PGBOUNCER_LOG_DIR}}|$PGBOUNCER_LOG_DIR|g" \
        -e "s|{{PGBOUNCER_POOL_MODE}}|$PGBOUNCER_POOL_MODE|g" \
        -e "s|{{PGBOUNCER_MAX_CLIENT_CONN}}|$PGBOUNCER_MAX_CLIENT_CONN|g" \
        -e "s|{{PGBOUNCER_DEFAULT_POOL_SIZE}}|$PGBOUNCER_DEFAULT_POOL_SIZE|g" \
        -e "s|{{PGBOUNCER_MIN_POOL_SIZE}}|$PGBOUNCER_MIN_POOL_SIZE|g" \
        -e "s|{{PGBOUNCER_RESERVE_POOL_SIZE}}|$PGBOUNCER_RESERVE_POOL_SIZE|g" \
        -e "s|{{PGBOUNCER_RESERVE_POOL_TIMEOUT}}|$PGBOUNCER_RESERVE_POOL_TIMEOUT|g" \
        -e "s|{{PGBOUNCER_ADMIN_ROLE}}|$PGBOUNCER_ADMIN_ROLE|g" \
        -e "s|{{CLIENT_TLS_SSLMODE}}|${CLIENT_TLS_SSLMODE:-require}|g" \
        -e "s|{{SERVER_TLS_SSLMODE}}|${SERVER_TLS_SSLMODE:-disable}|g" \
        -e "s|{{SSL_CERT_PATH}}|$SSL_CERT_PATH|g" \
        -e "s|{{SSL_KEY_PATH}}|$SSL_KEY_PATH|g" \
        "$TEMPLATE_DIR/pgbouncer.ini.template" > "$CONFIG_DIR/pgbouncer.ini"
fi

# ============================================================================
# 產生 userlist.txt 認證檔
# 注意：userlist.txt 不可包含任何註解！
#      pgBouncer 會嚴格檢查格式，註解會導致 "broken auth file" 錯誤
#      格式必須是： "username" "scram-sha-256$iterations:salt$storedkey:serverkey"
# ============================================================================
print_info "產生 userlist.txt（使用 SCRAM-SHA-256 hash）"
cat > "$CONFIG_DIR/userlist.txt" <<EOF
"$PGBOUNCER_ADMIN_ROLE" "$PGBOUNCER_HASH"
"$CLIENT_ROLE" "$CLIENT_HASH"
EOF

# ============================================================================
# 設定檔案權限
# ============================================================================
chown pgbouncer:pgbouncer "$CONFIG_DIR/pgbouncer.ini" "$CONFIG_DIR/userlist.txt"
chmod 640 "$CONFIG_DIR/pgbouncer.ini"
chmod 640 "$CONFIG_DIR/userlist.txt"

print_success "設定檔建立完成"

# ============================================================================
# 顯示設定摘要
# ============================================================================
print_info "pgbouncer.ini 摘要:"
grep -E "^(listen_addr|listen_port|pool_mode|auth_type)" "$CONFIG_DIR/pgbouncer.ini" | sed 's/^/  /'

echo ""
print_info "userlist.txt 內容:"
sudo cat "$CONFIG_DIR/userlist.txt"

# 最終提醒
echo ""
print_info "後續步驟提醒："
echo "  1. 確認 userlist.txt 內容正確（不應包含註解或佔位符）"
echo "  2. 如果修改了設定檔，需要重新載入 pgBouncer："
echo "     sudo systemctl reload pgbouncer"
echo "  3. 測試連線："
echo "     psql -h 127.0.0.1 -p $PGBOUNCER_PORT -U $PGBOUNCER_ADMIN_ROLE -d pgbouncer"

print_success "步驟 7 完成"