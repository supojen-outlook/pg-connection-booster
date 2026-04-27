#!/bin/bash
# scripts/utils/common.sh - 共用函式庫

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全域變數
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
TOTAL_STEPS=13

# 載入環境變數
load_env() {
    local env_file="${PROJECT_DIR}/.env"
    if [ ! -f "$env_file" ]; then
        print_error "找不到 .env 檔案"
        exit 1
    fi
    set -a
    source "$env_file"
    set +a
}

# 列印函式
print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}➡️  $1${NC}"
}

print_step() {
    echo -e "\n${PURPLE}[$1/${TOTAL_STEPS}]${NC} $2"
}

# 顏色輸出函數
print_color() {
    local color=$1
    local message=$2
    case $color in
        RED) echo -e "${RED}${message}${NC}" ;;
        GREEN) echo -e "${GREEN}${message}${NC}" ;;
        YELLOW) echo -e "${YELLOW}${message}${NC}" ;;
        BLUE) echo -e "${BLUE}${message}${NC}" ;;
        PURPLE) echo -e "${PURPLE}${message}${NC}" ;;
        CYAN) echo -e "${CYAN}${message}${NC}" ;;
        *) echo "$message" ;;
    esac
}

# 檢查指令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 備份檔案
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "已備份 $file"
    fi
}

# 檢查是否為 root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "請使用 root 權限執行此腳本"
        exit 1
    fi
}

# 確認動作
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    
    if [ "$default" = "Y" ]; then
        read -p "$message (Y/n) " -n 1 -r
    else
        read -p "$message (y/N) " -n 1 -r
    fi
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}