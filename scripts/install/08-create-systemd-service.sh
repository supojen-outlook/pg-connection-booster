#!/bin/bash
# scripts/install/08-create-systemd-service.sh - 建立 systemd service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "8" "建立 systemd service"

SERVICE_FILE="/etc/systemd/system/pgbouncer.service"

# 備份現有服務檔案
if [ -f "$SERVICE_FILE" ]; then
    cp "$SERVICE_FILE" "${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 建立 service 檔案
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=pgBouncer Connection Pooler for PostgreSQL
After=network.target

[Service]
Type=forking
User=pgbouncer
Group=pgbouncer

Environment=PATH=$PGBOUNCER_PREFIX/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ExecStart=$PGBOUNCER_PREFIX/bin/pgbouncer -d -q $PGBOUNCER_CONFIG_DIR/pgbouncer.ini
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -INT \$MAINPID

PIDFile=$PGBOUNCER_RUN_DIR/pgbouncer.pid
RuntimeDirectory=pgbouncer

Restart=on-failure
RestartSec=5

TimeoutStartSec=60
TimeoutStopSec=30

LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF

# 設定權限
chmod 644 "$SERVICE_FILE"

# 重新載入 systemd
systemctl daemon-reload

print_success "systemd service 建立完成"

print_info "Service 設定摘要:"
echo "  - ExecStart: $PGBOUNCER_PREFIX/bin/pgbouncer -d -q $PGBOUNCER_CONFIG_DIR/pgbouncer.ini"
echo "  - PIDFile: $PGBOUNCER_RUN_DIR/pgbouncer.pid"
echo "  - User: pgbouncer"