#!/bin/bash
# scripts/utils/cert-monitor.sh - pgBouncer SSL 憑證監控腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

# 設定日誌檔案
LOG_FILE="/var/log/pgbouncer/ssl-monitor.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 日誌函數
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "INFO: $1"
}

log_warning() {
    log_message "WARNING: $1"
}

log_error() {
    log_message "ERROR: $1"
}

log_success() {
    log_message "SUCCESS: $1"
}

# 檢查必要參數
if [ -z "$SSL_DOMAIN" ]; then
    log_error "SSL_DOMAIN 未設定"
    exit 1
fi

# 憑證路徑設定
LE_CERT_DIR="/etc/letsencrypt/live/$SSL_DOMAIN"
LE_CERT="$LE_CERT_DIR/fullchain.pem"
LE_KEY="$LE_CERT_DIR/privkey.pem"
PG_SSL_DIR="/etc/pgbouncer/ssl"
PG_CURRENT_CERT="$PG_SSL_DIR/server.crt"
PG_CURRENT_KEY="$PG_SSL_DIR/server.key"
HASH_FILE="$PG_SSL_DIR/.last_hash"

log_info "開始憑證檢查 - 域名: $SSL_DOMAIN"

# 1. 檢查 Let's Encrypt 憑證是否存在
if [ ! -f "$LE_CERT" ] || [ ! -f "$LE_KEY" ]; then
    log_error "Let's Encrypt 憑證檔案不存在"
    log_error "  憑證: $LE_CERT"
    log_error "  私鑰: $LE_KEY"
    exit 1
fi

# 2. 計算當前憑證雜湊值
CURRENT_HASH=$(sha256sum "$LE_CERT" | cut -d' ' -f1)

# 3. 檢查是否需要更新
NEEDS_UPDATE=false
if [ ! -f "$HASH_FILE" ]; then
    log_info "首次執行，需要建立雜湊追蹤檔案"
    NEEDS_UPDATE=true
elif [ "$CURRENT_HASH" != "$(cat "$HASH_FILE" 2>/dev/null)" ]; then
    log_info "偵測到憑證變更"
    log_info "  舊雜湊: $(cat "$HASH_FILE" 2>/dev/null | head -c 12)..."
    log_info "  新雜湊: ${CURRENT_HASH:0:12}..."
    NEEDS_UPDATE=true
else
    log_info "憑證未變更，無需更新"
fi

# 4. 如果需要更新，執行更新程序
if [ "$NEEDS_UPDATE" = "true" ]; then
    log_info "開始更新 pgBouncer SSL 憑證"
    
    # 建立版本目錄
    TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
    VERSION_DIR="$PG_SSL_DIR/versions/$TIMESTAMP"
    
    if ! sudo mkdir -p "$VERSION_DIR"; then
        log_error "無法建立版本目錄: $VERSION_DIR"
        exit 1
    fi
    
    # 複製憑證檔案
    log_info "複製憑證檔案到版本目錄"
    if ! sudo cp "$LE_CERT" "$VERSION_DIR/server.crt"; then
        log_error "無法複製憑證檔案"
        exit 1
    fi
    
    if ! sudo cp "$LE_KEY" "$VERSION_DIR/server.key"; then
        log_error "無法複製私鑰檔案"
        exit 1
    fi
    
    # 原子性更新符號連結
    log_info "更新符號連結"
    TEMP_CERT_LINK="$PG_SSL_DIR/server.crt.tmp"
    TEMP_KEY_LINK="$PG_SSL_DIR/server.key.tmp"
    
    sudo ln -sf "$VERSION_DIR/server.crt" "$TEMP_CERT_LINK"
    sudo ln -sf "$VERSION_DIR/server.key" "$TEMP_KEY_LINK"
    
    sudo mv -T "$TEMP_CERT_LINK" "$PG_CURRENT_CERT"
    sudo mv -T "$TEMP_KEY_LINK" "$PG_CURRENT_KEY"
    
    # 設定權限
    log_info "設定檔案權限"
    sudo chown -R pgbouncer:pgbouncer "$PG_SSL_DIR"
    sudo chmod 640 "$PG_CURRENT_CERT"
    sudo chmod 600 "$PG_CURRENT_KEY"
    sudo chmod -R 640 "$VERSION_DIR"
    
    # 更新雜湊追蹤檔案
    echo "$CURRENT_HASH" | sudo tee "$HASH_FILE" > /dev/null
    
    # 清理舊版本（保留最近 3 個）
    log_info "清理舊版本"
    cd "$PG_SSL_DIR/versions"
    ls -t 2>/dev/null | tail -n +4 | xargs -r sudo rm -rf 2>/dev/null || true
    
    # 重啟 pgBouncer 服務
    log_info "重啟 pgBouncer 服務"
    if sudo systemctl restart pgbouncer; then
        log_success "pgBouncer 服務重啟成功"
        
        # 檢查服務狀態
        sleep 2
        if sudo systemctl is-active --quiet pgbouncer; then
            log_success "pgBouncer 服務運行正常"
        else
            log_error "pgBouncer 服務重啟後未運行"
            sudo systemctl status pgbouncer --no-pager | tail -10 >> "$LOG_FILE"
        fi
    else
        log_error "pgBouncer 服務重啟失敗"
        sudo systemctl status pgbouncer --no-pager | tail -10 >> "$LOG_FILE"
        exit 1
    fi
    
    log_success "SSL 憑證更新完成"
    log_info "版本資訊: $TIMESTAMP"
    
    # 顯示保留的版本數量
    VERSION_COUNT=$(ls -1 "$PG_SSL_DIR/versions" 2>/dev/null | wc -l)
    log_info "保留版本數量: $VERSION_COUNT"
    
else
    # 即使不需要更新，也檢查憑證有效期
    if command -v openssl >/dev/null 2>&1; then
        if ! openssl x509 -in "$PG_CURRENT_CERT" -noout -checkend 86400 >/dev/null 2>&1; then
            log_warning "憑證將在 24 小時內過期"
            
            # 顯示到期時間
            EXPIRY_DATE=$(openssl x509 -in "$PG_CURRENT_CERT" -noout -enddate | cut -d= -f2)
            log_warning "到期時間: $EXPIRY_DATE"
        fi
    fi
fi

log_info "憑證檢查完成"

# 顯示統計資訊
if [ -f "$LOG_FILE" ]; then
    TOTAL_CHECKS=$(grep -c "開始憑證檢查" "$LOG_FILE" 2>/dev/null || echo "0")
    UPDATES=$(grep -c "SSL 憑證更新完成" "$LOG_FILE" 2>/dev/null || echo "0")
    log_info "統計資訊: 總檢查 $TOTAL_CHECKS 次，更新 $UPDATES 次"
fi
