#!/bin/bash
# scripts/utils/setup-cron.sh - 設定 pgBouncer SSL 監控 cron 任務

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_info "設定 pgBouncer SSL 監控 cron 任務"

# 檢查必要參數
if [ -z "$SSL_DOMAIN" ]; then
    print_error "SSL_DOMAIN 未設定"
    exit 1
fi

# Cron 設定檔案
CRON_FILE="/etc/cron.d/pgbouncer-ssl"
MONITOR_SCRIPT="${SCRIPT_DIR}/scripts/utils/cert-monitor.sh"

# 檢查監控腳本是否存在
if [ ! -f "$MONITOR_SCRIPT" ]; then
    print_error "監控腳本不存在: $MONITOR_SCRIPT"
    exit 1
fi

# 確保監控腳本有執行權限
chmod +x "$MONITOR_SCRIPT"

# 建立 cron 任務
print_info "建立 cron 任務檔案: $CRON_FILE"

# 使用 here document 直接寫入檔案
sudo tee "$CRON_FILE" > /dev/null <<EOF
# pgBouncer SSL 憑證監控任務
# 每 15 分鐘檢查一次 Let's Encrypt 憑證更新
# 記錄到 /var/log/pgbouncer/ssl-monitor.log

*/15 * * * * pgbouncer $MONITOR_SCRIPT

# 每天凌晨 2 點清理舊日誌（保留最近 7 天）
0 2 * * * pgbouncer find /var/log/pgbouncer -name "ssl-monitor.log.*" -mtime +7 -delete 2>/dev/null || true
EOF

# 設定正確的權限
sudo chmod 644 "$CRON_FILE"

# 重新載入 cron 服務
print_info "重新載入 cron 服務"
if sudo systemctl is-active --quiet cron; then
    # cron.service 不支援 reload，使用 restart
    sudo systemctl restart cron
elif sudo systemctl is-active --quiet crond; then
    # crond 通常支援 reload
    sudo systemctl reload crond 2>/dev/null || sudo systemctl restart crond
else
    print_warning "無法確定 cron 服務名稱，嘗試重新載入"
    sudo systemctl restart cron 2>/dev/null || sudo systemctl restart crond 2>/dev/null || true
fi

# 建立日誌目錄
sudo mkdir -p /var/log/pgbouncer

# 驗證 cron 任務
print_info "驗證 cron 任務設定"
if [ -f "$CRON_FILE" ]; then
    print_success "cron 任務檔案已建立"
    echo "  檔案位置: $CRON_FILE"
    echo "  檢查頻率: 每 15 分鐘"
    echo "  監控腳本: $MONITOR_SCRIPT"
    echo "  日誌檔案: /var/log/pgbouncer/ssl-monitor.log"
else
    print_error "cron 任務檔案建立失敗"
    exit 1
fi

# 顯示當前 cron 任務
print_info "當前 pgBouncer 相關 cron 任務:"
sudo crontab -u pgbouncer -l 2>/dev/null || echo "  無現有任務"

print_success "cron 任務設定完成"
print_info "監控資訊："
echo "  憑證檢查: 每 15 分鐘"
echo "  日誌保留: 7 天"
echo "  手動執行: sudo -u pgbouncer $MONITOR_SCRIPT"
echo "  查看日誌: sudo tail -f /var/log/pgbouncer/ssl-monitor.log"
