#!/bin/bash
# scripts/install/10-create-pgbouncer-role.sh
# 功能：在 PostgreSQL 中建立 pgBouncer 管理角色
# 這個角色用於讓 pgBouncer 查詢系統狀態（連線數、統計資訊等）
# 會自動偵測並使用最適合的連線方式（sudo、密碼、Unix socket）

set -e

# 取得腳本所在目錄的上一層的上一層（專案根目錄）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# 載入共用函式庫（含顏色輸出、環境變數載入等）
source "${SCRIPT_DIR}/scripts/utils/common.sh"

# 載入 .env 中的環境變數
load_env

# 顯示目前執行的步驟編號和說明
print_step "9" "在 PostgreSQL 中建立 pgBouncer 管理角色"

# ===== 定義 SQL 指令 =====
# 把要執行的 SQL 先定義成變數，避免重複
SQL_COMMAND=$(cat <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$PGBOUNCER_ADMIN_ROLE') THEN
        CREATE ROLE $PGBOUNCER_ADMIN_ROLE WITH LOGIN PASSWORD '$PGBOUNCER_ADMIN_PASSWORD';
        RAISE NOTICE '✅ pgBouncer 管理角色 % 建立完成', '$PGBOUNCER_ADMIN_ROLE';
    ELSE
        RAISE NOTICE 'ℹ️ pgBouncer 管理角色 % 已存在，跳過建立', '$PGBOUNCER_ADMIN_ROLE';
    END IF;
END
\$\$;

-- 授予必要的系統權限（這些是 pgBouncer 管理介面需要的）
-- pg_read_all_settings: 可以讀取所有系統設定參數
-- pg_read_all_stats: 可以讀取所有系統統計資訊
GRANT pg_read_all_settings TO $PGBOUNCER_ADMIN_ROLE;
GRANT pg_read_all_stats TO $PGBOUNCER_ADMIN_ROLE;

-- 驗證角色已成功建立或已存在
SELECT '角色狀態: ' || count(*) || ' 個 pgBouncer 管理角色' 
FROM pg_roles WHERE rolname = '$PGBOUNCER_ADMIN_ROLE';
EOF
)

# ===== 自動偵測並選擇最佳的連線方式 =====
print_info "檢測 PostgreSQL 連線方式..."

# 標記是否成功執行
EXECUTED=0

# 【方法1】嘗試用 sudo -u postgres（適用於本機 trust/peer 認證）
# 這是最常見的 Ubuntu PostgreSQL 安裝方式，不需要密碼 [citation:1][citation:3]
if sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
    print_success "使用 sudo -u postgres 連線 (Unix socket/peer 認證)"
    echo "$SQL_COMMAND" | sudo -u postgres psql || {
        print_error "執行 SQL 失敗"
        exit 1
    }
    EXECUTED=1

# 【方法2】如果 .env 有設定超級用戶密碼，用 TCP + 密碼認證
# 適用於遠端 PostgreSQL 或需要密碼認證的環境
elif [ -n "$PG_SUPER_PASSWORD" ]; then
    export PGPASSWORD="$PG_SUPER_PASSWORD"
    
    if [ -n "$PG_HOST" ] && [ "$PG_HOST" != "localhost" ]; then
        PSQL_CMD="psql -h $PG_HOST -p $PG_PORT -U $PG_SUPER_USER -d postgres"
    else
        PSQL_CMD="psql -h localhost -p $PG_PORT -U $PG_SUPER_USER -d postgres"
    fi
    print_success "使用 TCP 連線 (密碼認證)"
    echo "$SQL_COMMAND" | $PSQL_CMD || {
        print_error "執行 SQL 失敗"
        exit 1
    }
    EXECUTED=1
    unset PGPASSWORD

# 【方法3】最後嘗試用預設 Unix socket（無密碼）
# 適用於本機且 pg_hba.conf 設定為 trust 的環境
elif command -v psql &> /dev/null; then
    print_success "使用 Unix socket 連線 (無密碼)"
    echo "$SQL_COMMAND" | psql -U postgres -d postgres || {
        print_error "執行 SQL 失敗"
        exit 1
    }
    EXECUTED=1
fi

# ===== 檢查是否成功執行 =====
if [ $EXECUTED -eq 0 ]; then
    print_error "無法連線到 PostgreSQL"
    print_info "請確認："
    echo "  1. PostgreSQL 服務是否已啟動（sudo systemctl status postgresql）[citation:3]"
    echo "  2. 是否有安裝 postgresql-client（sudo apt install postgresql-client）[citation:8]"
    echo "  3. 或是在 .env 中設定正確的 PG_SUPER_PASSWORD"
    exit 1
fi

# ===== 顯示角色資訊 =====
print_success "pgBouncer 管理角色建立/確認完成"
echo ""
print_info "角色詳細資訊:"

# 嘗試用各種方式顯示角色資訊
if sudo -u postgres psql -c "\du $PGBOUNCER_ADMIN_ROLE" 2>/dev/null; then
    true
elif [ -n "$PG_SUPER_PASSWORD" ]; then
    export PGPASSWORD="$PG_SUPER_PASSWORD"
    psql -h ${PG_HOST:-localhost} -p $PG_PORT -U $PG_SUPER_USER -d postgres -c "\du $PGBOUNCER_ADMIN_ROLE" 2>/dev/null || true
    unset PGPASSWORD
fi

# ===== 完成 =====
print_success "步驟 10 完成"