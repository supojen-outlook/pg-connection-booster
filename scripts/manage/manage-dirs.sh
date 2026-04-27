#!/bin/bash
# scripts/manage/manage-dirs.sh - 目錄管理腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

ACTION=${1:-"check"}

# ===== 顯示使用說明 =====
show_usage() {
    echo -e "${YELLOW}使用方式:${NC}"
    echo -e "  $0 [動作]"
    echo ""
    echo -e "${YELLOW}動作:${NC}"
    echo -e "  check     檢查目錄狀態（預設）"
    echo -e "  fix-perms 修正目錄權限"
    echo -e "  create    建立目錄"
    echo -e "  delete    刪除目錄（危險）"
    echo ""
    echo -e "${YELLOW}範例:${NC}"
    echo -e "  $0 check"
    echo -e "  sudo $0 fix-perms"
    echo -e "  sudo $0 create"
    echo -e "  sudo $0 delete"
    echo ""
}

# ===== 檢查目錄 =====
check_dirs() {
    echo -e "${YELLOW}[檢查] 目錄狀態${NC}\n"
    
    # 安裝目錄
    echo -e "安裝目錄: $PGBOUNCER_PREFIX"
    if [ -d "$PGBOUNCER_PREFIX" ]; then
        PERMS=$(stat -c '%a' "$PGBOUNCER_PREFIX" 2>/dev/null || stat -f '%A' "$PGBOUNCER_PREFIX" 2>/dev/null)
        OWNER=$(stat -c '%U:%G' "$PGBOUNCER_PREFIX" 2>/dev/null || stat -f '%Su:%Sg' "$PGBOUNCER_PREFIX" 2>/dev/null)
        echo -e "  ${GREEN}✅ 存在${NC} (權限: $PERMS, 擁有者: $OWNER)"
    else
        echo -e "  ${RED}❌ 不存在${NC}"
    fi
    echo ""
    
    # 設定目錄
    echo -e "設定目錄: $PGBOUNCER_CONFIG_DIR"
    if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
        PERMS=$(stat -c '%a' "$PGBOUNCER_CONFIG_DIR" 2>/dev/null || stat -f '%A' "$PGBOUNCER_CONFIG_DIR" 2>/dev/null)
        OWNER=$(stat -c '%U:%G' "$PGBOUNCER_CONFIG_DIR" 2>/dev/null || stat -f '%Su:%Sg' "$PGBOUNCER_CONFIG_DIR" 2>/dev/null)
        echo -e "  ${GREEN}✅ 存在${NC} (權限: $PERMS, 擁有者: $OWNER)"
        if [ "$PERMS" != "750" ]; then
            echo -e "  ${RED}❌ 權限錯誤 (應為 750)${NC}"
        fi
        if [ "$OWNER" != "pgbouncer:pgbouncer" ]; then
            echo -e "  ${RED}❌ 擁有者錯誤 (應為 pgbouncer:pgbouncer)${NC}"
        fi
    else
        echo -e "  ${RED}❌ 不存在${NC}"
    fi
    echo ""
    
    # 日誌目錄
    echo -e "日誌目錄: $PGBOUNCER_LOG_DIR"
    if [ -d "$PGBOUNCER_LOG_DIR" ]; then
        PERMS=$(stat -c '%a' "$PGBOUNCER_LOG_DIR" 2>/dev/null || stat -f '%A' "$PGBOUNCER_LOG_DIR" 2>/dev/null)
        OWNER=$(stat -c '%U:%G' "$PGBOUNCER_LOG_DIR" 2>/dev/null || stat -f '%Su:%Sg' "$PGBOUNCER_LOG_DIR" 2>/dev/null)
        echo -e "  ${GREEN}✅ 存在${NC} (權限: $PERMS, 擁有者: $OWNER)"
        if [ "$PERMS" != "750" ]; then
            echo -e "  ${RED}❌ 權限錯誤 (應為 750)${NC}"
        fi
    else
        echo -e "  ${RED}❌ 不存在${NC}"
    fi
    echo ""
}

# ===== 修正權限 =====
fix_permissions() {
    echo -e "${YELLOW}[修正] 修正目錄權限${NC}\n"
    
    if ! id pgbouncer > /dev/null 2>&1; then
        print_error "pgbouncer 用戶不存在"
        exit 1
    fi
    
    # 安裝目錄
    if [ -d "$PGBOUNCER_PREFIX" ]; then
        chown -R pgbouncer:pgbouncer "$PGBOUNCER_PREFIX" 2>/dev/null || true
        chmod 755 "$PGBOUNCER_PREFIX"
        echo -e "  ✅ 修正 $PGBOUNCER_PREFIX -> 755 pgbouncer:pgbouncer"
    fi
    
    # 設定目錄
    if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
        chown -R pgbouncer:pgbouncer "$PGBOUNCER_CONFIG_DIR"
        chmod 750 "$PGBOUNCER_CONFIG_DIR"
        find "$PGBOUNCER_CONFIG_DIR" -type f -name "*.ini" -exec chmod 640 {} \;
        find "$PGBOUNCER_CONFIG_DIR" -type f -name "*.txt" -exec chmod 640 {} \;
        echo -e "  ✅ 修正 $PGBOUNCER_CONFIG_DIR 及其檔案權限"
    fi
    
    # 日誌目錄
    if [ -d "$PGBOUNCER_LOG_DIR" ]; then
        chown -R pgbouncer:pgbouncer "$PGBOUNCER_LOG_DIR"
        chmod 750 "$PGBOUNCER_LOG_DIR"
        echo -e "  ✅ 修正 $PGBOUNCER_LOG_DIR -> 750 pgbouncer:pgbouncer"
    fi
    
    # 運行目錄
    if [ -d "$PGBOUNCER_RUN_DIR" ]; then
        chown -R pgbouncer:pgbouncer "$PGBOUNCER_RUN_DIR"
        chmod 755 "$PGBOUNCER_RUN_DIR"
        echo -e "  ✅ 修正 $PGBOUNCER_RUN_DIR -> 755 pgbouncer:pgbouncer"
    fi
    
    echo -e "\n${GREEN}✅ 權限修正完成${NC}\n"
}

# ===== 建立目錄 =====
create_dirs() {
    echo -e "${YELLOW}[建立] 建立目錄${NC}\n"
    
    # 安裝目錄
    if [ ! -d "$PGBOUNCER_PREFIX" ]; then
        mkdir -p "$PGBOUNCER_PREFIX"/{bin,lib,share}
        echo -e "  ✅ 建立 $PGBOUNCER_PREFIX"
    fi
    
    # 設定目錄
    if [ ! -d "$PGBOUNCER_CONFIG_DIR" ]; then
        mkdir -p "$PGBOUNCER_CONFIG_DIR"
        echo -e "  ✅ 建立 $PGBOUNCER_CONFIG_DIR"
    fi
    
    # 日誌目錄
    if [ ! -d "$PGBOUNCER_LOG_DIR" ]; then
        mkdir -p "$PGBOUNCER_LOG_DIR"
        echo -e "  ✅ 建立 $PGBOUNCER_LOG_DIR"
    fi
    
    # 運行目錄
    if [ ! -d "$PGBOUNCER_RUN_DIR" ]; then
        mkdir -p "$PGBOUNCER_RUN_DIR"
        echo -e "  ✅ 建立 $PGBOUNCER_RUN_DIR"
    fi
    
    echo -e "\n${GREEN}✅ 目錄建立完成${NC}\n"
    fix_permissions
}

# ===== 刪除目錄 =====
delete_dirs() {
    echo -e "${RED}[刪除] 刪除目錄${NC}\n"
    echo -e "${RED}⚠️  警告：這將永久刪除以下目錄！${NC}"
    echo -e "  - $PGBOUNCER_CONFIG_DIR"
    echo -e "  - $PGBOUNCER_LOG_DIR"
    echo -e "  - $PGBOUNCER_RUN_DIR"
    echo ""
    
    read -p "是否確認刪除？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  刪除已取消${NC}"
        exit 0
    fi
    
    read -p "真的確定？輸入 YES 確認: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo -e "${YELLOW}⚠️  刪除已取消${NC}"
        exit 0
    fi
    
    # 刪除設定目錄
    if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
        rm -rf "$PGBOUNCER_CONFIG_DIR"
        echo -e "  ✅ 已刪除: $PGBOUNCER_CONFIG_DIR"
    fi
    
    # 刪除日誌目錄
    if [ -d "$PGBOUNCER_LOG_DIR" ]; then
        rm -rf "$PGBOUNCER_LOG_DIR"
        echo -e "  ✅ 已刪除: $PGBOUNCER_LOG_DIR"
    fi
    
    # 刪除運行目錄
    if [ -d "$PGBOUNCER_RUN_DIR" ]; then
        rm -rf "$PGBOUNCER_RUN_DIR"
        echo -e "  ✅ 已刪除: $PGBOUNCER_RUN_DIR"
    fi
    
    echo -e "\n${GREEN}✅ 目錄刪除完成${NC}\n"
}

# ===== 主程式 =====
main() {
    case "$ACTION" in
        create)
            if [ "$EUID" -ne 0 ]; then
                print_error "建立目錄需要 root 權限"
                exit 1
            fi
            create_dirs
            ;;
        fix-perms)
            if [ "$EUID" -ne 0 ]; then
                print_error "修正權限需要 root 權限"
                exit 1
            fi
            fix_permissions
            ;;
        delete)
            if [ "$EUID" -ne 0 ]; then
                print_error "刪除目錄需要 root 權限"
                exit 1
            fi
            delete_dirs
            ;;
        check|*)
            check_dirs
            ;;
    esac
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

main "$@"