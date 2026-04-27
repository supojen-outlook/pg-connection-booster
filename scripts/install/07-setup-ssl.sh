#!/bin/bash
# scripts/install/13-setup-ssl.sh - 設定 pgBouncer SSL/TLS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "7" "設定 pgBouncer SSL/TLS"

# 檢查必要參數
if [ -z "$SSL_DOMAIN" ]; then
    print_error "SSL_DOMAIN 未設定"
    exit 1
fi

print_info "SSL 設定參數："
echo "  域名: $SSL_DOMAIN"
echo "  憑證來源: /etc/letsencrypt/live/$SSL_DOMAIN/"
echo "  目標路徑: /etc/pgbouncer/ssl/"

# 1. 檢查 Let's Encrypt 憑證是否存在
LE_CERT_DIR="/etc/letsencrypt/live/$SSL_DOMAIN"
if [ ! -d "$LE_CERT_DIR" ]; then
    print_error "Let's Encrypt 憑證目錄不存在: $LE_CERT_DIR"
    print_info "請先使用 certbot 取得憑證："
    echo "  certbot certonly -d $SSL_DOMAIN"
    exit 1
fi

LE_CERT="$LE_CERT_DIR/fullchain.pem"
LE_KEY="$LE_CERT_DIR/privkey.pem"

if [ ! -f "$LE_CERT" ] || [ ! -f "$LE_KEY" ]; then
    print_error "Let's Encrypt 憑證檔案不存在："
    echo "  憑證: $LE_CERT"
    echo "  私鑰: $LE_KEY"
    exit 1
fi

# 2. 建立 pgBouncer SSL 目錄
PG_SSL_DIR="/etc/pgbouncer/ssl"
PG_SSL_VERSIONS_DIR="$PG_SSL_DIR/versions"

print_info "建立 pgBouncer SSL 目錄結構"
sudo mkdir -p "$PG_SSL_DIR"
sudo mkdir -p "$PG_SSL_VERSIONS_DIR"

# 3. 建立版本管理
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
VERSION_DIR="$PG_SSL_VERSIONS_DIR/$TIMESTAMP"

print_info "建立版本目錄: $VERSION_DIR"
sudo mkdir -p "$VERSION_DIR"

# 4. 複製憑證檔案
print_info "複製 SSL 憑證檔案"

# 複製到版本目錄
sudo cp "$LE_CERT" "$VERSION_DIR/server.crt"
sudo cp "$LE_KEY" "$VERSION_DIR/server.key"

# 複製到主要位置（符號連結）
sudo ln -sf "$VERSION_DIR/server.crt" "$PG_SSL_DIR/server.crt"
sudo ln -sf "$VERSION_DIR/server.key" "$PG_SSL_DIR/server.key"

# 5. 設定檔案權限和擁有者
print_info "設定檔案權限和擁有者"
sudo chown pgbouncer:pgbouncer "$PG_SSL_DIR"
sudo chown -R pgbouncer:pgbouncer "$PG_SSL_VERSIONS_DIR"
sudo chmod 755 "$PG_SSL_DIR"
sudo chmod 755 "$PG_SSL_VERSIONS_DIR"

# 設定實際憑證檔案權限（不是符號連結）
sudo chmod 640 "$VERSION_DIR/server.crt"
sudo chmod 600 "$VERSION_DIR/server.key"

# 確保符號連結的正確擁有者
sudo chown -h pgbouncer:pgbouncer "$PG_SSL_DIR/server.crt"
sudo chown -h pgbouncer:pgbouncer "$PG_SSL_DIR/server.key"

# 6. 建立憑證雜湊值追蹤
CERT_HASH=$(sha256sum "$LE_CERT" | cut -d' ' -f1)
echo "$CERT_HASH" | sudo tee "$PG_SSL_DIR/.last_hash" > /dev/null

# 7. 清理舊版本（保留最近 3 個）
print_info "清理舊版本（保留最近 3 個）"
cd "$PG_SSL_VERSIONS_DIR"
ls -t | tail -n +4 | xargs -r sudo rm -rf 2>/dev/null || true

# 8. 驗證憑證
print_info "驗證 SSL 憑證"
if command -v openssl >/dev/null 2>&1; then
    if openssl x509 -in "$PG_SSL_DIR/server.crt" -noout -checkend 86400 >/dev/null 2>&1; then
        print_success "憑證有效（24小時內不會過期）"
    else
        print_warning "憑證即將過期或無效"
        
        # 顯示到期時間
        EXPIRY_DATE=$(openssl x509 -in "$PG_SSL_DIR/server.crt" -noout -enddate | cut -d= -f2)
        echo "  到期時間: $EXPIRY_DATE"
    fi
else
    print_warning "openssl 命令不存在，跳過憑證驗證"
fi

# 9. 顯示版本資訊
print_info "憑證版本資訊："
echo "  當前版本: $TIMESTAMP"
echo "  保留版本數: $(ls -1 "$PG_SSL_VERSIONS_DIR" 2>/dev/null | wc -l)"
echo "  憑證雜湊: ${CERT_HASH:0:12}..."

# 10. 準備 SSL 設定（設定檔尚未建立，先準備環境）
print_info "準備 SSL 設定環境"
print_info "SSL 憑證已準備完成，將在設定檔建立時自動啟用"
print_info "憑證檔案位置："
echo "  當前憑證: $PG_SSL_DIR/server.crt"
echo "  當前私鑰: $PG_SSL_DIR/server.key"
echo "  版本目錄: $PG_SSL_VERSIONS_DIR"

# 11. 測試 pgBouncer 二進位檔案
print_info "測試 pgBouncer 二進位檔案"
if command -v /usr/local/pgbouncer/bin/pgbouncer >/dev/null 2>&1; then
    # 基本語法檢查：確保沒有明顯的語法錯誤
    if sudo -u pgbouncer /usr/local/pgbouncer/bin/pgbouncer -h >/dev/null 2>&1; then
        print_success "pgBouncer 二進位檔案可執行"
        echo "  版本資訊："
        sudo -u pgbouncer /usr/local/pgbouncer/bin/pgbouncer -V | sed 's/^/    /'
    else
        print_error "pgBouncer 二進位檔案無法執行"
        exit 1
    fi
else
    print_warning "pgBouncer 二進位檔案不存在，跳過二進位檔案測試"
fi

print_success "pgBouncer SSL/TLS 設定完成"
print_info "憑證管理資訊："
echo "  憑證目錄: $PG_SSL_DIR"
echo "  版本目錄: $PG_SSL_VERSIONS_DIR"
echo "  當前憑證: $PG_SSL_DIR/server.crt"
echo "  當前私鑰: $PG_SSL_DIR/server.key"
echo "  設定檔備份: /etc/pgbouncer/pgbouncer.ini.backup"
echo ""
print_info "定期檢查將透過 cron 任務自動執行憑證更新"
