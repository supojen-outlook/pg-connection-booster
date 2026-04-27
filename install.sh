#!/bin/bash
# install.sh - pgBouncer 整合安裝腳本
# ============================================================================
# 安裝步驟順序說明：
#   1-6:   環境準備、編譯安裝（不需要 PostgreSQL 角色）
#   7:     建立系統服務（不需要 PostgreSQL 角色）
#   8-9:   建立角色和資料庫（需要在 PostgreSQL 中建立角色）
#   10:    建立設定檔（此時角色已存在，可以取得正確的 hash）
#   11-12: 啟動服務和驗證
# ============================================================================

set -e

# ===== 設定顏色輸出 =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ===== 取得腳本所在目錄 =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 載入環境變數 =====
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
else
    echo -e "${RED}❌ 找不到 .env 檔案${NC}"
    echo -e "請複製 .env.example 為 .env 並設定正確的參數"
    exit 1
fi

SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# ===== 顯示標題 =====
show_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}    pgBouncer 完整安裝腳本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}執行時間:${NC} $(date)"
    echo -e "${YELLOW}安裝目錄:${NC} $SCRIPT_DIR"
    echo -e "${YELLOW}pgBouncer 版本:${NC} $PGBOUNCER_VERSION"
    echo -e "${YELLOW}應用程式資料庫:${NC} $APP_DB_NAME"
    echo -e "${BLUE}========================================${NC}\n"
}

# ===== 檢查執行權限 =====
check_root() {
    echo -e "${YELLOW}[1/3] 檢查執行權限...${NC}"
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ 請使用 root 權限執行此腳本${NC}"
        echo -e "請執行: sudo $0"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 權限檢查通過${NC}\n"
}

# ===== 確認安裝 =====
confirm_install() {
    echo -e "${YELLOW}[2/3] 確認安裝...${NC}"
    
    echo -e "${YELLOW}即將執行以下安裝步驟：${NC}"
    echo -e "  ${GREEN}【第一階段：環境準備】${NC}"
    echo -e "  1. ${GREEN}01-check-environment.sh${NC}   - 檢查環境"
    echo -e "  2. ${GREEN}02-install-dependencies.sh${NC} - 安裝相依套件"
    echo -e "  3. ${GREEN}03-create-system-user.sh${NC}   - 建立系統用戶"
    echo -e "  4. ${GREEN}04-create-directories.sh${NC}   - 建立目錄結構"
    echo -e "  5. ${GREEN}05-download-source.sh${NC}      - 下載原始碼"
    echo -e "  6. ${GREEN}06-compile-pgbouncer.sh${NC}    - 編譯安裝"
    echo -e ""
    echo -e "  ${GREEN}【第二階段：系統服務】${NC}"
    echo -e "  7. ${GREEN}08-create-systemd-service.sh${NC} - 建立 systemd 服務"
    echo -e ""
    echo -e "  ${GREEN}【第三階段：資料庫角色建立】${NC}"
    echo -e "  8. ${GREEN}10-create-pgbouncer-role.sh${NC} - 建立 pgBouncer 管理角色"
    echo -e "  9. ${GREEN}11-create-app-database.sh${NC}   - 建立應用程式資料庫"
    echo -e ""
    echo -e "  ${GREEN}【第四階段：設定檔與啟動】${NC}"
    echo -e " 10. ${GREEN}07-create-config.sh${NC}        - 建立設定檔（使用已存在的角色 hash）"
    echo -e " 11. ${GREEN}09-start-service.sh${NC}        - 啟動服務"
    echo -e " 12. ${GREEN}12-verify-installation.sh${NC}  - 驗證安裝"
    echo ""
    
    read -p "是否繼續安裝？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  安裝已取消${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}✅ 確認完成\n"
}

# ===== 執行安裝步驟 =====
run_installation() {
    echo -e "\n${BLUE}========== 開始安裝 ==========${NC}\n"
    
    # ------------------------------------------------------------------------
    # 第一階段：環境準備（不需要 PostgreSQL 角色）
    # ------------------------------------------------------------------------
    echo -e "${GREEN}【第一階段：環境準備】${NC}"
    "${SCRIPTS_DIR}/install/01-check-environment.sh"
    "${SCRIPTS_DIR}/install/02-install-dependencies.sh"
    "${SCRIPTS_DIR}/install/03-create-system-user.sh"
    "${SCRIPTS_DIR}/install/04-create-directories.sh"
    "${SCRIPTS_DIR}/install/05-download-source.sh"
    "${SCRIPTS_DIR}/install/06-compile-pgbouncer.sh"
    
    # ------------------------------------------------------------------------
    # 第二階段：SSL 設定（編譯完成後，設定檔建立前）
    # ------------------------------------------------------------------------
    echo -e "\n${GREEN}【第二階段：SSL 設定】${NC}"
    "${SCRIPTS_DIR}/install/07-setup-ssl.sh"      # 設定 SSL/TLS
    
    # ------------------------------------------------------------------------
    # 第三階段：系統服務（不需要 PostgreSQL 角色）
    # ------------------------------------------------------------------------
    echo -e "\n${GREEN}【第三階段：系統服務】${NC}"
    "${SCRIPTS_DIR}/install/08-create-systemd-service.sh"
    
    # ------------------------------------------------------------------------
    # 第四階段：資料庫角色建立（需要在 PostgreSQL 中建立角色）
    # ------------------------------------------------------------------------
    echo -e "\n${GREEN}【第四階段：資料庫角色建立】${NC}"
    "${SCRIPTS_DIR}/install/09-create-pgbouncer-role.sh"
    "${SCRIPTS_DIR}/install/10-create-app-database.sh"
    
    # ------------------------------------------------------------------------
    # 第五階段：設定檔與服務啟動（此時角色已存在，可以取得正確的 hash）
    # ------------------------------------------------------------------------
    echo -e "\n${GREEN}【第五階段：設定檔與服務啟動】${NC}"
    "${SCRIPTS_DIR}/install/11-create-config.sh"    # 現在可以取得真實的 hash
    "${SCRIPTS_DIR}/install/12-start-service.sh"
    "${SCRIPTS_DIR}/install/13-verify-installation.sh"
}

# ===== 顯示摘要 =====
show_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}✅ pgBouncer 安裝完成！${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    echo -e "${YELLOW}連線資訊:${NC}"
    echo -e "  - pgBouncer 埠: ${GREEN}$PGBOUNCER_PORT${NC}"
    echo -e "  - 應用程式資料庫: ${GREEN}$APP_DB_NAME${NC}"
    echo -e "  - 客戶端角色: ${GREEN}$CLIENT_ROLE${NC}"
    echo -e "  - 管理介面角色: ${GREEN}$PGBOUNCER_ADMIN_ROLE${NC}"
    echo ""
    
    echo -e "${YELLOW}系統整合:${NC}"
    echo -e "  ✅ systemd 服務: pgbouncer.service"
    echo -e "  ✅ 設定目錄: $PGBOUNCER_CONFIG_DIR"
    echo -e "  ✅ 日誌目錄: $PGBOUNCER_LOG_DIR"
    echo ""
    
    echo -e "${YELLOW}管理指令:${NC}"
    echo -e "  ${GREEN}make pg-status${NC}    - 查看狀態"
    echo -e "  ${GREEN}make pg-start${NC}     - 啟動服務"
    echo -e "  ${GREEN}make pg-stop${NC}      - 停止服務"
    echo -e "  ${GREEN}make pg-log${NC}       - 查看日誌"
    echo -e "  ${GREEN}make add-role${NC}     - 新增客戶端角色"
    echo -e "  ${GREEN}make ssl-setup${NC}    - 手動設定 SSL"
    echo -e "  ${GREEN}make ssl-monitor${NC}  - 手動檢查憑證"
    echo ""
    
    echo -e "${YELLOW}連線字串範例:${NC}"
    echo -e "  ${CYAN}應用程式連線 (psql):${NC}"
    echo -e "    本地連線:    psql -h 127.0.0.1 -p $PGBOUNCER_PORT -U $CLIENT_ROLE -d $APP_DB_NAME"
    echo -e "    遠端連線:    psql -h <SERVER_IP> -p $PGBOUNCER_PORT -U $CLIENT_ROLE -d $APP_DB_NAME"
    echo -e "    SSL 連線:     psql \"host=<SERVER_IP> port=$PGBOUNCER_PORT dbname=$APP_DB_NAME user=$CLIENT_ROLE sslmode=require\""
    echo ""
    echo -e "  ${CYAN}.NET Core Connection String:${NC}"
    echo -e "    一般連線:    Host=127.0.0.1;Port=$PGBOUNCER_PORT;Database=$APP_DB_NAME;Username=$CLIENT_ROLE;Password=your_password"
    echo -e "    SSL 連線:     Host=127.0.0.1;Port=$PGBOUNCER_PORT;Database=$APP_DB_NAME;Username=$CLIENT_ROLE;Password=your_password;SslMode=Require"
    echo ""
    echo -e "  ${CYAN}管理介面連線:${NC}"
    echo -e "    psql -h 127.0.0.1 -p $PGBOUNCER_PORT -U $PGBOUNCER_ADMIN_ROLE -d pgbouncer"
    echo ""
    
    echo -e "${YELLOW}遠端連線設定:${NC}"
    echo -e "  1. 確認防火牆開放 $PGBOUNCER_PORT 埠"
    echo -e "  2. 檢查 pgBouncer 監聽地址: listen_addr = *"
    echo -e "  3. 使用 SSL 連線確保安全性 (推薦)"
    echo -e "  4. 確認用戶有遠端連線權限"
    echo ""
    
    echo -e "${BLUE}========================================${NC}"
}

# ===== 主程式 =====
main() {
    show_header
    check_root
    confirm_install
    
    START_TIME=$(date +%s)
    
    run_installation
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    show_summary
    
    # 設定 SSL 監控 cron 任務
    if [ -f "${SCRIPTS_DIR}/utils/setup-cron.sh" ]; then
        echo -e "\n${YELLOW}設定 SSL 監控任務...${NC}"
        chmod +x "${SCRIPTS_DIR}/utils/setup-cron.sh"
        echo "  執行 cron 設定腳本..."
        "${SCRIPTS_DIR}/utils/setup-cron.sh"
        echo "  ✅ cron 任務設定完成"
    else
        echo -e "\n${YELLOW}跳過 SSL 監控任務設定 (腳本不存在)${NC}"
    fi
    
    echo -e "${GREEN}✨ 總安裝時間: ${DURATION} 秒${NC}"
}

main "$@"