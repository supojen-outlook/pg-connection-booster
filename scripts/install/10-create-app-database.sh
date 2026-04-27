#!/bin/bash
# scripts/install/11-create-app-database.sh
# 功能：建立應用程式資料庫和客戶端角色
# 1. 建立資料庫擁有者（可自訂名稱）
# 2. 建立應用程式資料庫（指定擁有者）
# 3. 建立客戶端角色（給應用程式用）
# 4. 授予適當權限（CONNECT, USAGE, CRUD）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "10" "建立應用程式資料庫和客戶端角色"

# ===== 定義 SQL 指令 =====
# 1. 建立資料庫擁有者的 SQL
CREATE_OWNER_SQL() {
    cat <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$APP_DB_OWNER') THEN
        CREATE ROLE $APP_DB_OWNER WITH LOGIN PASSWORD '$APP_DB_OWNER_PASSWORD' CREATEDB;
        RAISE NOTICE '✅ 資料庫擁有者 % 建立完成', '$APP_DB_OWNER';
    ELSE
        RAISE NOTICE 'ℹ️ 資料庫擁有者 % 已存在，跳過建立', '$APP_DB_OWNER';
    END IF;
END
\$\$;
EOF
}

# 2. 建立客戶端角色的 SQL
CREATE_CLIENT_SQL() {
    cat <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$CLIENT_ROLE') THEN
        CREATE ROLE $CLIENT_ROLE WITH LOGIN PASSWORD '$CLIENT_PASSWORD';
        RAISE NOTICE '✅ 客戶端角色 % 建立完成', '$CLIENT_ROLE';
    ELSE
        RAISE NOTICE 'ℹ️ 客戶端角色 % 已存在，跳過建立', '$CLIENT_ROLE';
    END IF;
END
\$\$;

GRANT CONNECT ON DATABASE $APP_DB_NAME TO $CLIENT_ROLE;
EOF
}

# 3. 授予 Schema 權限的 SQL（需要在目標資料庫中執行）
GRANT_SCHEMA_SQL() {
    cat <<EOF
GRANT USAGE ON SCHEMA public TO $CLIENT_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $CLIENT_ROLE;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $CLIENT_ROLE;
EOF
}

# ===== 自動偵測並選擇最佳的連線方式 =====
print_info "檢測 PostgreSQL 連線方式..."

# 標記是否成功執行
EXECUTED=0

# 【方法1】嘗試用 sudo -u postgres（適用於本機 trust/peer 認證）
if sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
    print_success "使用 sudo -u postgres 連線 (Unix socket/peer 認證)"
    
    # 建立資料庫擁有者
    CREATE_OWNER_SQL | sudo -u postgres psql || {
        print_error "建立資料庫擁有者失敗"
        exit 1
    }
    
    # 建立資料庫（不能用 DO 區塊，要直接執行）
    print_info "檢查資料庫 $APP_DB_NAME 是否存在..."
    if sudo -u postgres psql -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '$APP_DB_NAME'" | grep -q 1; then
        print_info "資料庫 $APP_DB_NAME 已存在，跳過建立"
    else
        sudo -u postgres psql -d postgres -c "CREATE DATABASE $APP_DB_NAME OWNER $APP_DB_OWNER;"
        print_success "資料庫 $APP_DB_NAME 建立完成"
    fi
    
    # 建立客戶端角色
    CREATE_CLIENT_SQL | sudo -u postgres psql || {
        print_error "建立客戶端角色失敗"
        exit 1
    }
    
    # 授予 schema 權限（需要在目標資料庫中執行）
    GRANT_SCHEMA_SQL | sudo -u postgres psql -d "$APP_DB_NAME" || {
        print_error "授予 schema 權限失敗"
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
    
    # 建立資料庫擁有者
    CREATE_OWNER_SQL | $PSQL_CMD || {
        print_error "建立資料庫擁有者失敗"
        exit 1
    }
    
    # 建立資料庫
    print_info "檢查資料庫 $APP_DB_NAME 是否存在..."
    if $PSQL_CMD -t -c "SELECT 1 FROM pg_database WHERE datname = '$APP_DB_NAME'" | grep -q 1; then
        print_info "資料庫 $APP_DB_NAME 已存在，跳過建立"
    else
        $PSQL_CMD -c "CREATE DATABASE $APP_DB_NAME OWNER $APP_DB_OWNER;"
        print_success "資料庫 $APP_DB_NAME 建立完成"
    fi
    
    # 建立客戶端角色
    CREATE_CLIENT_SQL | $PSQL_CMD || {
        print_error "建立客戶端角色失敗"
        exit 1
    }
    
    # 授予 schema 權限
    export PGPASSWORD="$PG_SUPER_PASSWORD"
    GRANT_SCHEMA_SQL | psql -h ${PG_HOST:-localhost} -p $PG_PORT -U $PG_SUPER_USER -d "$APP_DB_NAME" || {
        print_error "授予 schema 權限失敗"
        exit 1
    }
    
    EXECUTED=1
    unset PGPASSWORD

# 【方法3】最後嘗試用預設 Unix socket（無密碼）
elif command -v psql &> /dev/null; then
    print_success "使用 Unix socket 連線 (無密碼)"
    
    # 建立資料庫擁有者
    CREATE_OWNER_SQL | psql -U postgres -d postgres || {
        print_error "建立資料庫擁有者失敗"
        exit 1
    }
    
    # 建立資料庫
    print_info "檢查資料庫 $APP_DB_NAME 是否存在..."
    if psql -U postgres -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '$APP_DB_NAME'" | grep -q 1; then
        print_info "資料庫 $APP_DB_NAME 已存在，跳過建立"
    else
        psql -U postgres -d postgres -c "CREATE DATABASE $APP_DB_NAME OWNER $APP_DB_OWNER;"
        print_success "資料庫 $APP_DB_NAME 建立完成"
    fi
    
    # 建立客戶端角色
    CREATE_CLIENT_SQL | psql -U postgres -d postgres || {
        print_error "建立客戶端角色失敗"
        exit 1
    }
    
    # 授予 schema 權限
    GRANT_SCHEMA_SQL | psql -U postgres -d "$APP_DB_NAME" || {
        print_error "授予 schema 權限失敗"
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

# ===== 顯示建立結果 =====
print_success "應用程式資料庫和客戶端角色建立完成"
echo ""
print_info "建立結果摘要:"
echo "  - 資料庫擁有者: $APP_DB_OWNER"
echo "  - 應用程式資料庫: $APP_DB_NAME"
echo "  - 客戶端角色: $CLIENT_ROLE"

# 嘗試顯示資料庫資訊
echo ""
print_info "資料庫確認:"
if sudo -u postgres psql -c "\l $APP_DB_NAME" 2>/dev/null; then
    true
elif [ -n "$PG_SUPER_PASSWORD" ]; then
    export PGPASSWORD="$PG_SUPER_PASSWORD"
    psql -h ${PG_HOST:-localhost} -p $PG_PORT -U $PG_SUPER_USER -d postgres -c "\l $APP_DB_NAME" 2>/dev/null || true
    unset PGPASSWORD
fi

# ===== 完成 =====
print_success "步驟 11 完成"