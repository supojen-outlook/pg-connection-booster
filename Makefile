# Makefile for pgBouncer Installation and Management
# 使用方法: make [command]

.PHONY: help install uninstall check-status manage-dirs backup-config setup-permissions \
        pg-status pg-start pg-stop pg-restart pg-reload pg-log add-role remove-role list-roles deploy reset-db

# 顏色定義
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
CYAN = \033[0;36m
NC = \033[0m

# 預設目標
.DEFAULT_GOAL := help

## 顯示這個幫助訊息
help:
	@echo -e "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo -e "$(BLUE) pgBouncer 安裝與管理 Makefile$(NC)"
	@echo -e "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo -e "$(CYAN)安裝相關指令:$(NC)"
	@echo -e "  $(GREEN)make install$(NC)              - 完整安裝 pgBouncer"
	@echo -e "  $(GREEN)make uninstall$(NC)            - 解除安裝 pgBouncer"
	@echo -e "  $(GREEN)make setup-permissions$(NC)    - 設定所有腳本執行權限"
	@echo -e ""
	@echo -e "$(CYAN)日常管理指令:$(NC)"
	@echo -e "  $(GREEN)make check-status$(NC)         - 檢查 pgBouncer 狀態"
	@echo -e "  $(GREEN)make pg-start$(NC)             - 啟動 pgBouncer 服務"
	@echo -e "  $(GREEN)make pg-stop$(NC)              - 停止 pgBouncer 服務"
	@echo -e "  $(GREEN)make pg-restart$(NC)           - 重啟 pgBouncer 服務"
	@echo -e "  $(GREEN)make pg-reload$(NC)            - 重新載入設定檔"
	@echo -e "  $(GREEN)make pg-log$(NC)               - 查看即時日誌"
	@echo -e ""
	@echo -e "$(CYAN)角色管理指令:$(NC)"
	@echo -e "  $(GREEN)make add-role$(NC)              - 新增客戶端角色"
	@echo -e "  $(GREEN)make remove-role$(NC)           - 移除客戶端角色"
	@echo -e "  $(GREEN)make list-roles$(NC)            - 列出所有角色"
	@echo -e "  $(GREEN)make reset-db$(NC)              - 重置資料庫（刪除並重新建立）"
	@echo -e ""
	@echo -e "$(CYAN)其他工具:$(NC)"
	@echo -e "  $(GREEN)make manage-dirs$(NC)          - 管理目錄 (check/fix-perms)"
	@echo -e "  $(GREEN)make backup-config$(NC)        - 備份配置檔案"
	@echo -e ""
	@echo -e "$(YELLOW)使用前準備:$(NC)"
	@echo -e "  1. $(CYAN)cp .env.example .env$(NC)           - 複製環境變數範例"
	@echo -e "  2. $(CYAN)vim .env$(NC)                       - 修改密碼等設定"
	@echo -e "  3. $(CYAN)make setup-permissions$(NC)        - 設定腳本執行權限"
	@echo -e "  4. $(CYAN)sudo make install$(NC)              - 開始安裝"
	@echo -e ""
	@echo -e ""
	@echo -e "$(YELLOW)⚠️  重要提醒:$(NC)"
	@echo -e "  $(GREEN)make deploy$(NC)               - 部署專案到遠端伺服器 (在工作電腦上執行)"
	@echo -e ""
	@echo -e "$(YELLOW)注意:$(NC) 安裝需要 root 權限"
	@echo -e "$(BLUE)════════════════════════════════════════════════════════════$(NC)"

# ===== 安裝相關 =====

## 設定所有腳本執行權限
setup-permissions:
	@echo -e "$(BLUE)▶ 設定腳本執行權限$(NC)"
	@chmod +x install.sh uninstall.sh deploy.sh 2>/dev/null || true
	@chmod +x scripts/install/*.sh 2>/dev/null || true
	@chmod +x scripts/uninstall/*.sh 2>/dev/null || true
	@chmod +x scripts/manage/*.sh 2>/dev/null || true
	@chmod +x scripts/utils/common.sh 2>/dev/null || true
	@chmod +x scripts/manage/reset-database.sh 2>/dev/null || true
	@echo -e "$(GREEN)✅ 所有腳本權限設定完成$(NC)"

## 完整安裝 pgBouncer
install: setup-permissions
	@echo -e "$(BLUE)▶ 開始安裝 pgBouncer$(NC)"
	@if [ ! -f .env ]; then \
		echo -e "$(RED)❌ 找不到 .env 檔案$(NC)"; \
		echo -e "$(YELLOW)請先執行: cp .env.example .env$(NC)"; \
		exit 1; \
	fi
	@sudo ./install.sh

## 解除安裝 pgBouncer
uninstall:
	@echo -e "$(RED)⚠️  警告: 這個動作會移除 pgBouncer 及其所有資料！$(NC)"
	@printf "確定要繼續嗎？ (y/N) "; \
	read REPLY; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		sudo ./uninstall.sh; \
	else \
		echo -e "$(GREEN)取消解除安裝$(NC)"; \
	fi

# ===== 日常管理指令 =====

## 檢查 pgBouncer 狀態
check-status:
	@echo -e "$(BLUE)▶ pgBouncer 狀態$(NC)"
	@systemctl status pgbouncer --no-pager || true

## 啟動 pgBouncer 服務
pg-start:
	@echo -e "$(BLUE)▶ 啟動 pgBouncer 服務$(NC)"
	@sudo systemctl start pgbouncer
	@sudo systemctl status pgbouncer --no-pager | head -n 5

## 停止 pgBouncer 服務
pg-stop:
	@echo -e "$(BLUE)▶ 停止 pgBouncer 服務$(NC)"
	@sudo systemctl stop pgbouncer
	@echo -e "$(GREEN)✅ pgBouncer 已停止$(NC)"

## 重啟 pgBouncer 服務
pg-restart:
	@echo -e "$(BLUE)▶ 重啟 pgBouncer 服務$(NC)"
	@sudo systemctl restart pgbouncer
	@sudo systemctl status pgbouncer --no-pager | head -n 5

## 重新載入 pgBouncer 設定檔
pg-reload:
	@echo -e "$(BLUE)▶ 重新載入 pgBouncer 設定檔$(NC)"
	@sudo systemctl reload pgbouncer
	@echo -e "$(GREEN)✅ 設定檔已重新載入$(NC)"

## 查看 pgBouncer 即時日誌
pg-log:
	@echo -e "$(BLUE)▶ pgBouncer 即時日誌 (Ctrl+C 離開)$(NC)"
	@sudo tail -f /var/log/pgbouncer/pgbouncer.log 2>/dev/null || echo "❌ 找不到日誌檔案"

# ===== 角色管理 =====

## 新增客戶端角色
add-role:
	@echo -e "$(BLUE)▶ 新增客戶端角色$(NC)"
	@read -p "資料庫名稱: " DB_NAME; \
	read -p "角色名稱: " ROLE_NAME; \
	read -s -p "密碼: " ROLE_PASSWORD; \
	echo ""; \
	read -s -p "確認密碼: " CONFIRM_PASSWORD; \
	echo ""; \
	if [ "$$ROLE_PASSWORD" != "$$CONFIRM_PASSWORD" ]; then \
		echo -e "$(RED)❌ 密碼不符$(NC)"; \
		exit 1; \
	fi; \
	./scripts/manage/add-client-role.sh "$$DB_NAME" "$$ROLE_NAME" "$$ROLE_PASSWORD"

## 移除客戶端角色
remove-role:
	@echo -e "$(BLUE)▶ 移除客戶端角色$(NC)"
	@read -p "角色名稱: " ROLE_NAME; \
	./scripts/manage/remove-client-role.sh "$$ROLE_NAME"

## 列出所有角色
list-roles:
	@echo -e "$(BLUE)▶ 列出所有角色$(NC)"
	@./scripts/manage/list-roles.sh

# ===== 其他工具 =====

## 管理目錄 (check/fix-perms)
manage-dirs:
	@echo -e "$(BLUE)▶ 目錄管理$(NC)"
	@./scripts/manage/manage-dirs.sh

## 快速檢查目錄
check-dirs:
	@./scripts/manage/manage-dirs.sh check

## 修正目錄權限
fix-perms:
	@sudo ./scripts/manage/manage-dirs.sh fix-perms

## 備份配置檔案
backup-config:
	@echo -e "$(BLUE)▶ 備份配置檔案$(NC)"
	@sudo ./scripts/manage/backup-config.sh

## 顯示環境資訊
show-env:
	@echo -e "$(BLUE)▶ 環境資訊$(NC)"
	@echo -e "  $(CYAN)系統記憶體:$(NC) $$(grep MemTotal /proc/meminfo | awk '{print $$2/1024/1024 " GB"}')"
	@echo -e "  $(CYAN)CPU 核心數:$(NC) $$(nproc)"
	@echo -e "  $(CYAN)磁碟空間:$(NC) $$(df -h / | awk 'NR==2 {print $$4 " 可用"}')"
	@if [ -f .env ]; then \
		echo -e "  $(CYAN)pgBouncer 版本:$(NC) $$(grep PGBOUNCER_VERSION .env | cut -d'=' -f2)"; \
	fi

## 部署專案到遠端伺服器
deploy:
	@echo -e "$(BLUE)▶ 部署專案到遠端伺服器$(NC)"
	@./deploy.sh

## 重置資料庫（刪除並重新建立，保留角色）
reset-db:
	@echo -e "$(BLUE)▶ 重置資料庫$(NC)"
	@./scripts/manage/reset-database.sh