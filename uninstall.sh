#!/bin/bash
# uninstall.sh - pgBouncer 整合卸載腳本

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

# ===== 預設參數（可被 .env 覆蓋）=====
KEEP_DATA=${KEEP_DATA:-false}
KEEP_CONFIG=${KEEP_CONFIG:-false}
KEEP_SYSTEM_CONFIG=${KEEP_SYSTEM_CONFIG:-false}
SKIP_BACKUP=${SKIP_BACKUP:-false}

# ===== 顯示標題 =====
show_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${RED}    pgBouncer 完整卸載腳本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}執行時間:${NC} $(date)"
    echo -e "${YELLOW}保留數據:${NC} $KEEP_DATA"
    echo -e "${YELLOW}保留配置:${NC} $KEEP_CONFIG"
    echo -e "${YELLOW}保留系統配置:${NC} $KEEP_SYSTEM_CONFIG"
    echo -e "${BLUE}========================================${NC}\n"
}

# ===== 檢查執行權限 =====
check_root() {
    echo -e "${YELLOW}[1/4] 檢查執行權限...${NC}"
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ 請使用 root 權限執行此腳本${NC}"
        echo -e "請執行: sudo $0"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 權限檢查通過${NC}\n"
}

# ===== 顯示卸載影響 =====
show_impact() {
    echo -e "${YELLOW}[2/4] 影響分析${NC}"
    echo ""
    
    if [ -d "$PGBOUNCER_PREFIX" ]; then
        echo -e "  ${RED}⚠️  pgBouncer 安裝目錄: $PGBOUNCER_PREFIX${NC}"
    fi
    
    if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
        CONFIG_SIZE=$(du -sh "$PGBOUNCER_CONFIG_DIR" 2>/dev/null | cut -f1)
        echo -e "  ${RED}⚠️  設定目錄: $PGBOUNCER_CONFIG_DIR (${CONFIG_SIZE})${NC}"
    fi
    
    if [ -d "$PGBOUNCER_LOG_DIR" ]; then
        LOG_SIZE=$(du -sh "$PGBOUNCER_LOG_DIR" 2>/dev/null | cut -f1)
        echo -e "  ${RED}⚠️  日誌目錄: $PGBOUNCER_LOG_DIR (${LOG_SIZE})${NC}"
    fi
    
    if id pgbouncer > /dev/null 2>&1; then
        echo -e "  ${RED}⚠️  pgbouncer 用戶 (UID: $(id -u pgbouncer))${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}卸載選項:${NC}"
    echo -e "  - KEEP_DATA=${KEEP_DATA}          # true: 保留日誌和運行目錄"
    echo -e "  - KEEP_CONFIG=${KEEP_CONFIG}      # true: 保留設定檔"
    echo -e "  - KEEP_SYSTEM_CONFIG=${KEEP_SYSTEM_CONFIG} # true: 保留系統用戶"
    echo -e "  - SKIP_BACKUP=${SKIP_BACKUP}      # true: 跳過備份"
    echo ""
}

# ===== 確認卸載 =====
confirm_uninstall() {
    echo -e "${YELLOW}[3/4] 確認卸載${NC}"
    
    echo -e "${RED}⚠️  警告：此操作將永久刪除 pgBouncer！${NC}"
    read -p "是否確認卸載？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  卸載已取消${NC}"
        exit 0
    fi
    
    echo -e "${RED}⚠️  最後一次機會！${NC}"
    read -p "輸入 YES 確認卸載: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo -e "${YELLOW}⚠️  卸載已取消${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}✅ 確認完成\n"
}

# ===== 執行卸載步驟 =====
run_uninstallation() {
    echo -e "${YELLOW}[4/4] 執行卸載步驟${NC}\n"
    
    # 設定環境變數給子腳本
    export KEEP_DATA KEEP_CONFIG KEEP_SYSTEM_CONFIG SKIP_BACKUP
    
    "${SCRIPTS_DIR}/uninstall/01-stop-service.sh"
    "${SCRIPTS_DIR}/uninstall/02-remove-config.sh"
    "${SCRIPTS_DIR}/uninstall/03-uninstall-pgbouncer.sh"
    "${SCRIPTS_DIR}/uninstall/04-cleanup-environment.sh"
    
    # 清理 SSL 相關檔案
    echo -e "${YELLOW}清理 SSL 檔案...${NC}"
    
    # 移除 cron 任務
    if [ -f "/etc/cron.d/pgbouncer-ssl" ]; then
        echo "  移除 cron 任務: /etc/cron.d/pgbouncer-ssl"
        sudo rm -f "/etc/cron.d/pgbouncer-ssl"
        sudo systemctl reload cron 2>/dev/null || sudo systemctl reload crond 2>/dev/null || true
    fi
    
    # 清理 SSL 目錄
    if [ -d "/etc/pgbouncer/ssl" ]; then
        echo "  清理 SSL 目錄: /etc/pgbouncer/ssl"
        if [ "$KEEP_CONFIG" != "true" ]; then
            sudo rm -rf "/etc/pgbouncer/ssl"
            echo "  ✅ SSL 目錄已移除"
        else
            echo "  ⚠️  SSL 目錄已保留 (KEEP_CONFIG=true)"
        fi
    fi
    
    # 清理日誌目錄中的 SSL 監控日誌
    if [ -f "/var/log/pgbouncer/ssl-monitor.log" ]; then
        if [ "$KEEP_DATA" != "true" ]; then
            echo "  清理 SSL 監控日誌"
            sudo rm -f "/var/log/pgbouncer/ssl-monitor.log"*
        else
            echo "  ⚠️  SSL 監控日誌已保留 (KEEP_DATA=true)"
        fi
    fi
    
    echo "  ✅ SSL 清理完成"
}

# ===== 顯示摘要 =====
show_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${GREEN}✅ pgBouncer 卸載完成${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ "$KEEP_DATA" = "true" ]; then
        echo -e "${YELLOW}日誌目錄已保留:${NC} $PGBOUNCER_LOG_DIR"
    fi
    
    if [ "$KEEP_CONFIG" = "true" ]; then
        echo -e "${YELLOW}設定目錄已保留:${NC} $PGBOUNCER_CONFIG_DIR"
    fi
    
    if [ "$KEEP_SYSTEM_CONFIG" = "true" ]; then
        echo -e "${YELLOW}系統用戶已保留:${NC} pgbouncer"
    fi
    
    if [ "$SKIP_BACKUP" != "true" ]; then
        echo -e "${YELLOW}備份檔案:${NC} /tmp/pgbouncer-backup-*.tar.gz"
    fi
    
    echo -e "${BLUE}========================================${NC}"
}

# ===== 主程式 =====
main() {
    show_header
    check_root
    show_impact
    confirm_uninstall
    
    START_TIME=$(date +%s)
    
    run_uninstallation
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    show_summary
    echo -e "${GREEN}✨ 卸載花費時間: ${DURATION} 秒${NC}"
}

main "$@"