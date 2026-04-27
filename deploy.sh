#!/bin/bash

set -e

echo "=== SSH Host Alias 設定說明 ==="
echo "請先在 ~/.ssh/config 檔案中加入以下設定："
echo ""
echo "Host <你的別名名稱>"
echo "    HostName <伺服器IP或網域名稱>"
echo "    User <使用者名稱>"
echo "    IdentityFile ~/.ssh/<私鑰檔案名稱>"
echo ""
echo "例如："
echo "Host ocean"
echo "    HostName 192.168.1.100"
echo "    User ubuntu"
echo "    IdentityFile ~/.ssh/id_rsa"
echo "================================"
echo ""

# Prompt for SSH host alias
host=""
while [ -z "$host" ]; do
    read -p "請輸入 SSH host alias: " host
    if [ -z "$host" ]; then
        echo "Host alias 不能為空，請重新輸入。"
    fi
done

echo "正在部署到主機: $host"
rsync -avz --exclude '.git' ./ "$host":~/pgbouncer/

echo "部署完成！"
