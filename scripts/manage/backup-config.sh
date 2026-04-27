#!/bin/bash
# scripts/manage/backup-config.sh - 備份配置檔案

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_header "備份 pgBouncer 配置檔案"

BACKUP_DIR="/tmp/pgbouncer-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}備份目錄:${NC} $BACKUP_DIR"
echo ""

# 備份設定檔
if [ -d "$PGBOUNCER_CONFIG_DIR" ]; then
    cp -r "$PGBOUNCER_CONFIG_DIR" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✅${NC} 設定目錄 (完整備份)"
    
    # 列出備份的檔案
    echo -e "     檔案列表:"
    ls -la "$PGBOUNCER_CONFIG_DIR" | grep -E "\.(ini|txt)$" | sed 's/^/      /'
else
    echo -e "  ${RED}❌${NC} 設定目錄不存在"
fi

# 備份 service 檔案
if [ -f "/etc/systemd/system/pgbouncer.service" ]; then
    cp "/etc/systemd/system/pgbouncer.service" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✅${NC} systemd service 檔案"
fi

# 備份環境變數
if [ -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✅${NC} .env 檔案"
fi

# 建立備份資訊
cat > "$BACKUP_DIR/backup-info.txt" <<EOF
備份時間: $(date)
pgBouncer 版本: $PGBOUNCER_VERSION
設定目錄: $PGBOUNCER_CONFIG_DIR
日誌目錄: $PGBOUNCER_LOG_DIR
備份檔案列表:
EOF

ls -la "$BACKUP_DIR" >> "$BACKUP_DIR/backup-info.txt"

# 壓縮備份
cd /tmp
tar -czf "pgbouncer-backup-$(date +%Y%m%d_%H%M%S).tar.gz" -C "$BACKUP_DIR" .
rm -rf "$BACKUP_DIR"

echo ""
echo -e "${GREEN}✅ 備份完成！${NC}"
echo -e "   壓縮檔: ${CYAN}/tmp/pgbouncer-backup-$(date +%Y%m%d_%H%M%S).tar.gz${NC}"
echo -e "   大小: $(du -h /tmp/pgbouncer-backup-$(date +%Y%m%d_%H%M%S).tar.gz | cut -f1)"