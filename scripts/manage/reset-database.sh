#!/bin/bash
# scripts/manage/reset-database.sh - 重置資料庫（刪除並重新建立）
# 功能：
#   1. 刪除現有資料庫（使用 WITH FORCE 強制斷開連線）
#   2. 重新建立資料庫（保留既有的資料庫擁有者和客戶端角色）
#   3. 重新授予客戶端角色權限

set -e

# 取得腳本所在目錄的上一層的上一層（專案根目錄）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# 載入共用函式庫（含顏色輸出、環境變數載入等）
source "${SCRIPT_DIR}/scripts/utils/common.sh"

# 載入 .env 中的環境變數
load_env

# 顯示警告並確認
print_header "重置資料庫"
print_warning "這將刪除資料庫 '${APP_DB_NAME}' 並重新建立！"
print_info "資料庫擁有者 '${APP_DB_OWNER}' 和客戶端角色 '${CLIENT_ROLE}' 將保留。"
echo ""

if ! confirm_action "確定要繼續嗎"; then
    print_info "已取消重置"
    exit 0
fi

# ===== 定義 SQL 指令 =====

# 1. 刪除資料庫的 SQL
DROP_DB_SQL="DROP DATABASE IF EXISTS $APP_DB_NAME WITH (FORCE);"

# 2. 建立資料庫的 SQL
CREATE_DB_SQL="CREATE DATABASE $APP_DB_NAME OWNER $APP_DB_OWNER;"

# 3. 授予資料庫連線權限的 SQL
GRANT_DB_SQL="GRANT CONNECT ON DATABASE $APP_DB_NAME TO $CLIENT_ROLE;"

# 4. 授予 Schema 權限的 SQL（需要在目標資料庫中執行）
GRANT_SCHEMA_SQL=$(cat <<EOF
GRANT USAGE ON SCHEMA public TO $CLIENT_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $CLIENT_ROLE;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $CLIENT_ROLE;
EOF
)

# ===== 自動偵測並選擇最佳的連線方式 =====
print_info "檢測 PostgreSQL 連線方式..."

# 標記是否成功執行
EXECUTED=0

# 【方法1】嘗試用 sudo -u postgres（適用於本機 trust/peer 認證）
if sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
    print_success "使用 sudo -u postgres 連線 (Unix socket/peer 認證)"
    
    # 刪除資料庫
    print_info "正在刪除資料度 '$APP_DB_NAME'..."
    echo "$DROP_DB_SQL" | sudo -u postgres psql -d postgres || {
        print_error "刪除資料庫失敗"
        exit 1
    }
    print_success "資料庫已刪除"
    
    # 建立資料庫
    print_info "正在建立資料庫 '$APP_DB_NAME'（擁有者: $APP_DB_OWNER）..."
    echo "$CREATE_DB_SQL" | sudo -u postgres psql -d postgres || {
        print_error "建立資料庫失敗"
        exit 1
    }
    print_success "資料庫建立完成"
    
    # 授予資料庫連線權限
    print_info "正在授予資料庫連線權限..."
    echo "$GRANT_DB_SQL" | sudo -u postgres psql -d postgres || {
        print_error "授予資料庫權限失敗"
        exit 1
    }
    
    # 授予 Schema 權限（在目標資料庫中執行）
    print_info "正在授予 Schema 權限..."
    echo "$GRANT_SCHEMA_SQL" | sudo -u postgres psql -d "$APP_DB_NAME" || {
        print_error "授予 Schema 權限失敗"
        exit 1
    }
    
    EXECUTED=1

# 【方法2】如果 .env 有設定超級用戶密碼，用 TCP + 密碼認證
elif [ -n "$PG_SUPER_PASSWORD" ]; then
    export PGPASSWORD="$PG_SUPER_PASSWORD"
    
    if [ -n "$PG_HOST" ] && [ "$PG_HOST" != "localhost" ]; then
        PSQL_CMD="psql -h $PG_HOST -p $PG_PORT -U $PG_SUPER_USER -d postgres"
    else
        PSQL_CMD="psql -h localhost -p $PG_PORT -U $PG_SUPER_USER -d postgres"
    fi
    print_success "使用 TCP 連線 (密碼認證)"
    
    # 刪除資料庫
    print_info "正在刪除資料庫 '$APP_DB_NAME'..."
    echo "$DROP_DB_SQL" | $PSQL_CMD || {
        print_error "刪除資料庫失敗"
        exit 1
    }
    print_success "資料庫已刪除"
    
    # 建立資料庫
    print_info "正在建立資料庫 '$APP_DB_NAME'（擁有者: $APP_DB_OWNER）..."
    echo "$CREATE_DB_SQL" | $PSQL_CMD || {
        print_error "建立資料庫失敗"
        exit 1
    }
    print_success "資料庫建立完成"
    
    # 授予資料庫連線權限
    print_info "正在授予資料庫連線權限..."
    echo "$GRANT_DB_SQL" | $PSQL_CMD || {
        print_error "授予資料庫權限失敗"
        exit 1
    }
    
    # 授予 Schema 權限（在目標資料庫中執行）
    print_info "正在授予 Schema 權限..."
    echo "$GRANT_SCHEMA_SQL" | psql -h ${PG_HOST:-localhost} -p $PG_PORT -U $PG_SUPER_USER -d "$APP_DB_NAME" || {
        print_error "授予 Schema 權限失敗"
        exit 1
    }
    
    EXECUTED=1
    unset PGPASSWORD

# 【方法3】最後嘗試用預設 Unix socket（無密碼）
elif command -v psql &> /dev/null; then
    print_success "使用 Unix socket 連線 (無密碼)"
    
    # 刪除資料庫
    print_info "正在刪除資料庫 '$APP_DB_NAME'..."
    echo "$DROP_DB_SQL" | psql -U postgres -d postgres || {
        print_error "刪除資料庫失敗"
        exit 1
    }
    print_success "資料庫已刪除"
    
    # 建立資料庫
    print_info "正在建立資料庫 '$APP_DB_NAME'（擁有者: $APP_DB_OWNER）..."
    echo "$CREATE_DB_SQL" | psql -U postgres -d postgres || {
        print_error "建立資料庫失敗"
        exit 1
    }
    print_success "資料庫建立完成"
    
    # 授予資料庫連線權限
    print_info "正在授予資料庫連線權限..."
    echo "$GRANT_DB_SQL" | psql -U postgres -d postgres || {
        print_error "授予資料庫權限失敗"
        exit 1
    }
    
    # 授予 Schema 權限（在目標資料庫中執行）
    print_info "正在授予 Schema 權限..."
    echo "$GRANT_SCHEMA_SQL" | psql -U postgres -d "$APP_DB_NAME" || {
        print_error "授予 Schema 權限失敗"
        exit 1
    }
    
    EXECUTED=1
fi

# ===== 檢查是否成功執行 =====
if [ $EXECUTED -eq 0 ]; then
    print_error "無法連線到 PostgreSQL"
    print_info "請確認："
    echo "  1. PostgreSQL 服務是否已啟動（sudo systemctl status postgresql）"
    echo "  2. 是否有安裝 postgresql-client（sudo apt install postgresql-client）"
    echo "  3. 或是在 .env 中設定正確的 PG_SUPER_PASSWORD"
    exit 1
fi

# ===== 顯示結果 =====
echo ""
print_success "資料庫重置完成！"
print_info "摘要："
echo "  - 資料庫: $APP_DB_NAME"
echo "  - 擁有者: $APP_DB_OWNER"
echo "  - 客戶端角色: $CLIENT_ROLE"
echo "  - 權限: CONNECT, USAGE, CRUD"
