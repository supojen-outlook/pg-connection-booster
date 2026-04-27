# **pgBouncer 自動化安裝腳本**

## **專案概述**

這是一個自動化安裝腳本，用於在伺服器上安裝和配置 pgBouncer 連線池。pgBouncer 是一個輕量級的 PostgreSQL 連線池管理器，可以有效管理和重用資料庫連線，提升應用程式效能。

## **主要功能**

### **1. 自動化安裝 pgBouncer**
- 從原始碼編譯安裝最新版本的 pgBouncer
- 設定 systemd 服務，確保開機自動啟動
- 配置適當的系統用戶和權限

### **2. 資料庫環境設定**
- 在 PostgreSQL 中建立專用資料庫
- 建立資料庫擁有者角色和客戶端角色
- 設定適當的權限和存取控制

### **3. SSL/TLS 安全連線**
- 自動配置 Let's Encrypt SSL 憑證
- 啟用 pgBouncer 的 SSL 加密連線
- 設定定期憑證更新機制

### **4. 連線池管理**
- 配置最佳化的連線池參數
- 支援事務模式和連線池模式
- 提供監控和管理介面

## **架構說明**

```
客戶端應用程式 (API)
       ↓
pgBouncer 連線池 (埠 6432)
       ↓
PostgreSQL 資料庫 (埠 5432)
```

### **工作流程**
1. **客戶端連線**：後端 API 透過客戶端角色連接到 pgBouncer
2. **連線池管理**：pgBouncer 管理到 PostgreSQL 的連線池
3. **資料庫存取**：pgBouncer 將請求轉發到 PostgreSQL 資料庫
4. **資源優化**：重用連線，減少資料庫連線開銷

## **適用場景**

- **Web 應用程式**：需要高併發資料庫連線的 Web API
- **微服務架構**：多個服務共享同一個資料庫
- **效能優化**：減少資料庫連線建立和銷毀的開銷
- **資源管理**：控制資料庫連線數量，防止資源耗盡

## **安裝後的資源**

### **建立的資料庫物件**
- **資料庫**：`app` (可自訂名稱)
- **擁有者角色**：`doadmin` (可自訂)
- **客戶端角色**：`client` (可自訂)
- **管理角色**：`pgbouncer` (用於監控)

### **系統服務**
- **systemd 服務**：`pgbouncer.service`
- **設定檔**：`/etc/pgbouncer/pgbouncer.ini`
- **日誌目錄**：`/var/log/pgbouncer/`
- **SSL 憑證**：`/etc/pgbouncer/ssl/`

### **管理工具**
- `make pg-status` - 查看服務狀態
- `make pg-start` - 啟動服務
- `make pg-stop` - 停止服務
- `make pg-log` - 查看日誌
- `make add-role` - 新增客戶端角色
- `make ssl-setup` - 手動設定 SSL

---

## **安裝步驟（13個）**

### **步驟 1：01-check-environment.sh - 檢查環境**

**目的：** 確保系統環境符合安裝 pgBouncer 的基本要求

**具體操作：**
- 檢查是否以 root 權限執行（安裝需要 root 權限）
- 檢查必要指令是否存在：gcc、make、wget、tar、sed、awk、grep
- 檢查 PostgreSQL 是否可連線（使用 .env 中的資訊測試）
- 如果缺少指令會警告但不中斷（將在相依套件安裝步驟中補齊）

**為什麼需要：** 提前發現環境問題，避免安裝到一半失敗

---

### **步驟 2：02-install-dependencies.sh - 安裝編譯相依套件**

**目的：** 安裝編譯 pgBouncer 所需的所有開發套件

**具體操作：**
- 自動偵測作業系統（Ubuntu/Debian 或 RHEL/CentOS/Rocky）
- 根據系統類型安裝對應套件：
  - **Ubuntu/Debian：** build-essential、libevent-dev、libssl-dev、libc-ares-dev、wget、tar、make、gcc
  - **RHEL/CentOS/Rocky：** gcc、make、libevent-devel、openssl-devel、wget、tar、c-ares-devel
- 不支援的系統會直接失敗

**為什麼需要：** pgBouncer 是從原始碼編譯，需要這些開發套件才能編譯成功

---

### **步驟 3：03-create-system-user.sh - 建立 pgbouncer 系統用戶**

**目的：** 建立專門運行 pgBouncer 的系統用戶（非登入用戶）

**具體操作：**
- 建立 `pgbouncer` 系統群組（GID 從 .env 設定，預設 127）
- 建立 `pgbouncer` 系統用戶（UID 從 .env 設定，預設 121）
- 設定登入 shell 為 [/sbin/nologin](cci:7://file:///sbin/nologin:0:0-0:0)（禁止直接登入）
- 不建立家目錄（home-dir 設為 /nonexistent）
- 如果用戶或群組已存在，會顯示警告並檢查 UID/GID 是否符合預期
- 顯示最終用戶資訊（UID、GID、Shell）

**為什麼需要：** pgBouncer 需要專用系統用戶運行，不能直接登入是為了安全

---

### **步驟 4：04-create-directories.sh - 建立目錄結構**

**目的：** 建立所有 pgBouncer 需要的目錄

**具體操作：**
- 建立 `/usr/local/pgbouncer` 安裝目錄（包含 bin、lib、share 子目錄）
- 建立 `/etc/pgbouncer` 設定目錄（存放 ini、userlist 檔案）
- 建立 `/var/log/pgbouncer` 日誌目錄（存放 pgBouncer 日誌）
- 建立 `/var/run/pgbouncer` 運行目錄（存放 PID 檔案）
- 建立 `/usr/local/src` 原始碼目錄
- 設定目錄擁有者為 pgbouncer:pgbouncer
- 設定權限：設定目錄 750、日誌目錄 750、運行目錄 755

**為什麼需要：** pgBouncer 需要特定的目錄結構來存放執行檔、設定和日誌

---

### **步驟 5：05-download-source.sh - 下載 pgBouncer 原始碼**

**目的：** 從官方網站下載 pgBouncer 原始碼

**具體操作：**
- 從 pgBouncer 官方網站下載對應版本的 tar.gz 檔案
- 下載網址：`https://www.pgbouncer.org/downloads/files/{版本}/pgbouncer-{版本}.tar.gz`
- 如果已下載過，檢查檔案大小是否完整（小於 100KB 會重新下載）
- 顯示下載進度和檔案大小

**為什麼需要：** 需要原始碼才能編譯安裝 pgBouncer

---

### **步驟 6：06-compile-pgbouncer.sh - 編譯安裝 pgBouncer**

**目的：** 編譯並安裝 pgBouncer

**具體操作：**
- 檢查是否已安裝相同版本（避免重複編譯）
- 解壓縮原始碼 tar.gz
- 執行 `./configure` 設定編譯選項：
  - `--prefix`：安裝路徑（/usr/local/pgbouncer）
  - `--with-openssl`：啟用 SSL 加密
- 執行 `make -j$(nproc)` 使用所有 CPU 核心編譯
- 執行 `make install` 安裝到系統
- 驗證安裝是否成功（檢查執行檔是否存在並顯示版本）

**為什麼需要：** 從原始碼編譯可以確保安裝最新版本並啟用 SSL 支援

---

### **步驟 7：07-setup-ssl.sh - 設定 SSL/TLS**

**目的：** 設定 pgBouncer 的 SSL/TLS 憑證

**具體操作：**
- 檢查 Let's Encrypt 憑證是否存在（`/etc/letsencrypt/live/$SSL_DOMAIN/`）
- 建立 pgBouncer SSL 目錄結構（`/etc/pgbouncer/ssl/`）
- 建立版本管理目錄（保留最近 3 個版本）
- 複製憑證和私鑰到版本目錄
- 建立符號連結指向當前版本
- 設定檔案權限（憑證 640、私鑰 600、目錄 755）
- 建立憑證雜湊值追蹤檔案（`.last_hash`）
- 清理舊版本（只保留最近 3 個）
- 驗證憑證有效性（使用 openssl）
- 測試 pgBouncer 二進位檔案

**為什麼需要：** 讓 pgBouncer 支援 SSL 加密連線，保護客戶端到 pgBouncer 的傳輸安全

---

### **步驟 8：08-create-systemd-service.sh - 建立 systemd service**

**目的：** 建立 systemd 服務檔案，讓 pgBouncer 可以用 systemctl 管理

**具體操作：**
- 備份現有服務檔案（如果存在）
- 建立 `/etc/systemd/system/pgbouncer.service` 檔案：
  - 使用 `Type=forking` 模式（最穩定）
  - 以 pgbouncer 用戶身份運行
  - 設定環境變數（PATH）
  - 定義啟動指令：`pgbouncer -d -q pgbouncer.ini`
  - 定義重新載入指令：`kill -HUP $MAINPID`
  - 定義停止指令：`kill -INT $MAINPID`
  - 設定 PID 檔案路徑
  - 設定自動重啟策略（失敗時 5 秒後重啟）
  - 設定超時時間（啟動 60 秒、停止 30 秒）
  - 設定資源限制（最大檔案數 65536、最大程序數 65536）
- 設定檔案權限為 644
- 執行 `systemctl daemon-reload` 讓 systemd 讀取新服務

**為什麼需要：** systemd 是 Linux 標準服務管理器，讓 pgBouncer 可以開機自動啟動、自動重啟

---

### **步驟 9：09-create-pgbouncer-role.sh - 建立 pgBouncer 管理角色**

**目的：** 在 PostgreSQL 中建立 pgBouncer 管理角色，用於查詢系統狀態

**具體操作：**
- **自動偵測並選擇最佳的連線方式：**
  - 優先使用 `sudo -u postgres`（適用於本機 trust/peer 認證）
  - 其次使用 TCP + 密碼認證（如果 .env 有設定 PG_SUPER_PASSWORD）
  - 最後使用 Unix socket（無密碼）
- **執行 SQL：**
  - 建立角色（如果不存在）：`CREATE ROLE pgbouncer WITH LOGIN PASSWORD 'xxx'`
  - 授予系統權限：
    - `GRANT pg_read_all_settings`：可以讀取所有系統設定參數
    - `GRANT pg_read_all_stats`：可以讀取所有系統統計資訊
- 顯示角色建立結果和詳細資訊

**為什麼需要：** pgBouncer 管理介面需要這些權限來查詢連線數、統計資訊等

---

### **步驟 10：10-create-app-database.sh - 建立應用程式資料庫和客戶端角色**

**目的：** 建立應用程式資料庫、資料庫擁有者和客戶端角色

**具體操作：**
- **自動偵測連線方式**（與步驟 9 相同）
- **建立資料庫擁有者：**
  - 建立角色（如果不存在）：`CREATE ROLE doadmin WITH LOGIN PASSWORD 'xxx' CREATEDB`
- **建立應用程式資料庫：**
  - 檢查資料庫是否已存在
  - 如果不存在：`CREATE DATABASE app OWNER doadmin`
- **建立客戶端角色：**
  - 建立角色（如果不存在）：`CREATE ROLE client WITH LOGIN PASSWORD 'xxx'`
  - 授予連線權限：`GRANT CONNECT ON DATABASE app TO client`
- **授予 Schema 權限（在目標資料庫中執行）：**
  - `GRANT USAGE ON SCHEMA public TO client`
  - `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO client`
  - `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO client`（未來新建的表格也會自動繼承）
- 顯示建立結果摘要

**為什麼需要：** 建立應用程式實際使用的資料庫和角色，並設定適當權限

---

### **步驟 11：11-create-config.sh - 建立設定檔**

**目的：** 建立 pgbouncer.ini 和 userlist.txt 設定檔

**具體操作：**
- **備份現有設定檔**（如果存在）
- **從 PostgreSQL 取得角色的 SCRAM-SHA-256 hash：**
  - 自動偵測連線方式（優先使用 sudo -u postgres，其次 TCP+密碼，最後 Unix socket）
  - 查詢 pgbouncer 管理角色的密碼 hash
  - 查詢客戶端角色的密碼 hash
  - 如果找不到 hash 會報錯並提示先執行角色建立腳本
- **產生 pgbouncer.ini：**
  - 從模板 [config/pgbouncer.ini.template](cci:7://file:///Users/supojen/2026/save/bouncer-install/config/pgbouncer.ini.template:0:0-0:0) 替換變數
  - 替換變數包括：PG_HOST、PG_PORT、APP_DB_NAME、監聽位址、埠號、連線池設定等
  - 如果偵測到 SSL 憑證，自動啟用 SSL 設定
- **產生 userlist.txt：**
  - 格式必須是：`"username" "scram-sha-256$iterations:salt$storedkey:serverkey"`
  - **不可包含註解**（否則 pgBouncer 會報 "broken auth file" 錯誤）
  - 寫入 pgbouncer 管理角色和客戶端角色的 hash
- 設定檔案權限為 640（pgbouncer:pgbouncer）
- 顯示設定摘要和提醒

**為什麼需要：** 此腳本必須在角色建立後執行，因為需要從 PostgreSQL 取得正確的 SCRAM hash

---

### **步驟 12：12-start-service.sh - 啟動服務**

**目的：** 啟動 pgBouncer 服務並驗證運行正常

**具體操作：**
- 執行 `systemctl enable pgbouncer` 啟用開機啟動
- 執行 `systemctl start pgbouncer` 啟動服務
- 等待 2 秒讓服務啟動
- 檢查服務是否啟動成功
- 檢查是否監聽設定埠（預設 6432）
- 如果啟動失敗，顯示服務狀態

**為什麼需要：** 確保 pgBouncer 可以正常啟動並接受連線

---

### **步驟 13：13-verify-installation.sh - 驗證安裝結果**

**目的：** 全面檢查安裝是否成功

**具體操作：**
- 檢查 pgBouncer 服務是否運行中
- 檢查是否監聽正確的埠（預設 6432）
- 檢查設定檔是否存在（pgbouncer.ini、userlist.txt）
- 檢查 PostgreSQL 中的角色是否存在（pgbouncer 管理角色）
- 檢查 PostgreSQL 中的資料庫是否存在（應用程式資料庫）
- 檢查目錄權限是否正確（設定目錄應為 750）
- 統計失敗項目數量並顯示最終結果

**為什麼需要：** 確保所有步驟都成功完成，沒有遺漏或錯誤

---

## **卸載步驟（4個）**

### **卸載步驟 1：01-stop-service.sh - 停止服務**

**目的：** 停止 pgBouncer 服務並取消開機啟動

**具體操作：**
- 檢查服務是否運行中
- 如果運行中：執行 `systemctl stop pgbouncer` 和 `systemctl disable pgbouncer`
- 如果未運行：顯示警告

**為什麼需要：** 卸載前必須先停止服務，避免檔案被鎖定

---

### **卸載步驟 2：02-remove-config.sh - 移除配置**

**目的：** 備份並移除配置檔案

**具體操作：**
- **備份配置**（除非 SKIP_BACKUP=true）：
  - 建立備份目錄 `/tmp/pgbouncer-config-backup-時間戳`
  - 複製設定目錄和日誌目錄到備份目錄
- **刪除配置**（除非 KEEP_CONFIG=true）：
  - 刪除 `/etc/pgbouncer` 設定目錄
- 如果保留配置，顯示提示訊息

**為什麼需要：** 備份可以防止誤刪，KEEP_CONFIG 選項允許保留設定供重新安裝使用

---

### **卸載步驟 3：03-uninstall-pgbouncer.sh - 卸載 pgBouncer**

**目的：** 刪除 pgBouncer 安裝檔案和 systemd 服務

**具體操作：**
- 刪除 systemd service 檔案：`/etc/systemd/system/pgbouncer.service`
- 執行 `systemctl daemon-reload` 重新載入 systemd
- 刪除安裝目錄：`/usr/local/pgbouncer`（除非 KEEP_CONFIG=true）
- 刪除原始碼目錄：`/usr/local/src/pgbouncer-{版本}`
- 刪除原始碼壓縮檔：`/usr/local/src/pgbouncer-{版本}.tar.gz`

**為什麼需要：** 移除所有 pgBouncer 相關檔案和服務設定

---

### **卸載步驟 4：04-cleanup-environment.sh - 清理環境**

**目的：** 清理日誌、運行目錄和系統用戶

**具體操作：**
- **刪除日誌和運行目錄**（除非 KEEP_DATA=true）：
  - 刪除 `/var/log/pgbouncer` 日誌目錄
  - 刪除 `/var/run/pgbouncer` 運行目錄
- **刪除系統用戶和組**（除非 KEEP_SYSTEM_CONFIG=true）：
  - 檢查是否有程序在運行（如果有則跳過刪除）
  - 刪除 pgbouncer 用戶：`userdel pgbouncer`
  - 刪除 pgbouncer 組：`groupdel pgbouncer`
- 如果保留，顯示提示訊息

**為什麼需要：** 清理所有相關目錄和用戶，恢復系統到安裝前狀態

---

## **管理腳本（8個）**

### **管理腳本 1：add-client-role.sh - 新增客戶端角色**

**目的：** 新增一個新的客戶端角色到 PostgreSQL 和 pgBouncer

**具體操作：**
- 接收參數：資料庫名稱、角色名稱、密碼、擁有者（選填）
- 建立暫時的 .pgpass 檔案用於認證
- 在 PostgreSQL 中建立角色（如果不存在）
- 授予資料庫連線權限：`GRANT CONNECT ON DATABASE`
- 授予 Schema 權限（USAGE、CRUD）
- 將角色加入 pgBouncer userlist.txt
- 重新載入 pgBouncer 設定
- 刪除暫時檔案

**為什麼需要：** 方便新增新的應用程式用戶，自動處理 PostgreSQL 和 pgBouncer 的設定

---

### **管理腳本 2：backup-config.sh - 備份配置檔案**

**目的：** 備份所有 pgBouncer 相關配置檔案

**具體操作：**
- 建立備份目錄 `/tmp/pgbouncer-backup-時間戳`
- 備份設定目錄：`/etc/pgbouncer`
- 備份 systemd service 檔案：`/etc/systemd/system/pgbouncer.service`
- 備份 .env 檔案
- 建立備份資訊檔案（記錄備份時間、版本、檔案列表）
- 壓縮備份目錄為 tar.gz
- 顯示備份檔案路徑和大小

**為什麼需要：** 在修改設定前備份，可以快速回復

---

### **管理腳本 3：check-status.sh - 檢查 pgBouncer 狀態**

**目的：** 顯示 pgBouncer 的詳細狀態資訊

**具體操作：**
- 檢查服務狀態（運行中/未運行）
- 檢查監聽埠（顯示監聽資訊）
- 檢查設定檔是否存在（pgbouncer.ini、userlist.txt）
- 顯示重要設定（pool_mode、max_client_conn、default_pool_size）
- 顯示 userlist.txt 中的使用者數量
- 如果服務運行中，嘗試連線到管理介面顯示連線池狀態

**為什麼需要：** 快速了解 pgBouncer 的運行狀況和設定

---

### **管理腳本 4：list-roles.sh - 列出所有角色**

**目的：** 列出 pgBouncer userlist.txt 和 PostgreSQL 中的所有相關角色

**具體操作：**
- 讀取 userlist.txt 檔案
- 解析並顯示所有角色（跳過註解和空行）
- 統計角色總數
- 如果可以連線到 PostgreSQL，也列出 PostgreSQL 中的相關角色（pgbouncer_admin、資料庫擁有者、客戶端角色）

**為什麼需要：** 查看目前有哪些角色可以使用

---

### **管理腳本 5：manage-dirs.sh - 目錄管理**

**目的：** 檢查、修正、建立或刪除 pgBouncer 目錄

**具體操作：**
- **check（預設）：** 檢查所有目錄是否存在、權限和擁有者是否正確
- **fix-perms：** 修正所有目錄權限為正確值（設定目錄 750、日誌目錄 750、運行目錄 755），擁有者設為 pgbouncer:pgbouncer
- **create：** 建立所有目錄（需要 root 權限）
- **delete：** 刪除所有目錄（需要 root 權限，需要兩次確認）

**為什麼需要：** 統一管理所有 pgBouncer 目錄，方便檢查和修正權限問題

---

### **管理腳本 6：reload-config.sh - 重新載入設定檔**

**目的：** 重新載入 pgBouncer 設定檔（不中斷連線）

**具體操作：**
- 檢查 pgBouncer 是否運行中
- 檢查設定檔語法是否正確（使用 `pgbouncer -u` 驗證）
- 執行 `systemctl reload pgbouncer` 重新載入設定
- 顯示服務狀態（前 5 行）

**為什麼需要：** 修改設定後可以重新載入而不需要重啟服務，避免中斷現有連線

---

### **管理腳本 7：remove-client-role.sh - 移除客戶端角色**

**目的：** 從 pgBouncer 和 PostgreSQL 移除客戶端角色

**具體操作：**
- 接收參數：角色名稱
- 從 pgBouncer userlist.txt 中移除該角色
- 備份 userlist.txt
- 重新載入 pgBouncer 設定
- 詢問是否也要從 PostgreSQL 移除角色
- 如果確認，建立暫時的 .pgpass 檔案
- 從 PostgreSQL 撤銷權限並刪除角色
- 刪除暫時檔案

**為什麼需要：** 移除不再使用的角色，保持系統整潔

---

### **管理腳本 8：reset-database.sh - 重置資料庫**

**目的：** 刪除現有資料庫並重新建立（保留既有的角色）

**具體操作：**
- 顯示警告訊息並要求使用者確認（y/N）
- 自動偵測並選擇最佳的 PostgreSQL 連線方式：
  - 優先使用 `sudo -u postgres`（適用於本機 trust/peer 認證）
  - 其次使用 TCP + 密碼認證（如果 .env 有設定 PG_SUPER_PASSWORD）
  - 最後使用 Unix socket（無密碼）
- 執行 `DROP DATABASE IF EXISTS ... WITH (FORCE)` 強制刪除資料庫（斷開所有連線）
- 執行 `CREATE DATABASE ... OWNER ...` 重新建立資料庫
- 重新授予客戶端角色資料庫連線權限：`GRANT CONNECT ON DATABASE`
- 在目標資料庫中重新授予 Schema 權限：
  - `GRANT USAGE ON SCHEMA public`
  - `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES`
  - `ALTER DEFAULT PRIVILEGES`（未來新建的表格自動繼承權限）
- 顯示重置結果摘要

**為什麼需要：** 當資料庫被「玩壞」或需要清空資料重新開始時，可以快速重置資料庫而不需要重新建立角色

---

## **SSL/TLS 設定**

### **SSL 參數說明**

在 `.env` 檔案中可以設定以下 SSL 相關參數：

```bash
# SSL/TLS 設定
PGDATA="/var/lib/pgsql/data"              # PostgreSQL 資料目錄
SSL_CERT_PATH="${PGDATA}/server.crt"      # SSL 憑證檔案路徑
SSL_KEY_PATH="${PGDATA}/server.key"       # SSL 私鑰檔案路徑

# SSL 模式設定
CLIENT_TLS_SSLMODE="require"              # 前端 SSL（客戶端 -> pgBouncer）
SERVER_TLS_SSLMODE="disable"              # 後端 SSL（pgBouncer -> PostgreSQL）
```

### **SSL 模式選項**

**前端 SSL（CLIENT_TLS_SSLMODE）：**
- `require`：強制使用 SSL（推薦用於公網）
- `prefer`：優先使用 SSL，但也接受非 SSL
- `disable`：禁用 SSL
- `allow`：允許非 SSL，但嘗試使用 SSL

**後端 SSL（SERVER_TLS_SSLMODE）：**
- `require`：強制使用 SSL（用於遠端 PostgreSQL）
- `prefer`：優先使用 SSL，但也接受非 SSL
- `disable`：禁用 SSL（推薦用於同主機 Unix Socket）
- `allow`：允許非 SSL，但嘗試使用 SSL

### **推薦配置**

#### **場景 1：Docker Container + 同主機 PostgreSQL**
```bash
CLIENT_TLS_SSLMODE="require"    # 保護公網傳輸
SERVER_TLS_SSLMODE="disable"    # 使用 Unix Socket，更快
```

#### **場景 2：不同主機的 PostgreSQL**
```bash
CLIENT_TLS_SSLMODE="require"    # 保護公網傳輸
SERVER_TLS_SSLMODE="require"    # 保護內網傳輸
```

### **憑證設定**

pgBouncer 使用獨立的 SSL 憑證管理系統：

1. **Let's Encrypt 憑證來源**：`/etc/letsencrypt/live/${SSL_DOMAIN}/`
2. **pgBouncer 憑證位置**：`/etc/pgbouncer/ssl/`
3. **自動複製機制**：每 15 分鐘檢查憑證更新
4. **版本管理**：保留最近 3 個憑證版本

#### **手動設定 SSL**
```bash
# 執行 SSL 設定腳本
./scripts/install/13-setup-ssl.sh

# 手動檢查憑證更新
./scripts/utils/cert-monitor.sh

# 設定定期檢查任務
./scripts/utils/setup-cron.sh
```

#### **憑證目錄結構**
```
/etc/pgbouncer/ssl/
├── server.crt          # 當前憑證（符號連結）
├── server.key          # 當前私鑰（符號連結）
├── versions/          # 版本歷史
│   ├── 2024-04-26_13-30-00/
│   ├── 2024-04-26_14-15-00/
│   └── 2024-04-26_15-45-00/
└── .last_hash         # 憑證變更追蹤
```

### **連線字串範例**

#### **.NET Core Connection String**
```csharp
// 開發環境（不加密）
"Host=pgbouncer;Port=6432;Database=app;Username=client;Password=admin123;"

// 生產環境（加密）
"Host=pgbouncer;Port=6432;Database=app;Username=client;Password=admin123;SslMode=Require;"
```

#### **psql 連線**
```bash
# 一般連線
psql -h pgbouncer -p 6432 -U client -d app

# SSL 連線
psql "host=pgbouncer port=6432 dbname=app user=client sslmode=require"
```

### **驗證 SSL 設定**

```bash
# 檢查 pgBouncer 是否監聽 SSL
sudo ss -tlnp | grep :6432

# 檢查設定檔
grep -E "(client_tls|server_tls)" /etc/pgbouncer/pgbouncer.ini

# 檢查憑證檔案
ls -la /etc/pgbouncer/ssl/

# 檢查監控日誌
sudo tail -f /var/log/pgbouncer/ssl-monitor.log

# 測試 SSL 連線
openssl s_client -connect dev1.supojen.com:6432 -servername dev1.supojen.com

# 手動執行憑證檢查
sudo -u pgbouncer /path/to/bouncer-install/scripts/utils/cert-monitor.sh
```

---

# 安裝完成後，PostgreSQL Cluster 中新增的內容

## 1. 新增的角色 (Roles)
```sql
-- 用 \du 查看
                                   List of roles
    Role name     |                         Attributes                         
------------------+------------------------------------------------------------
 pgbouncer_admin  | Create role              ← pgBouncer 管理角色
 myapp_owner      | Create DB, Create role   ← 資料庫擁有者
 myapp_user       |                          ← 客戶端應用程式角色
```
這些角色的目的：
* pgbouncer_admin：讓 pgBouncer 可以查詢系統狀態，用於監控和管理
* myapp_owner：資料庫的擁有者，可以建立/修改資料庫物件
* myapp_user：應用程式實際使用的帳號，只有 CRUD 權限

## 2. 新增的資料庫 (Database)
```sql
-- 用 \l 查看
   Name    |  Owner      | Encoding | Collate | Ctype |   Access privileges   
-----------+-------------+----------+---------+-------+-----------------------
 myapp_db  | myapp_owner | UTF8     | C       | C     | =Tc/myapp_owner      +
           |             |          |         |       | myapp_owner=CTc/myapp_owner+
           |             |          |         |       | myapp_user=c/myapp_owner
```
這個資料庫的目的：
* 應用程式實際使用的資料庫
* 擁有者是 myapp_owner（不是 postgres）
* myapp_user 有 CONNECT 權限

## 3. 新增的權限 (Privileges)
```sql
-- 在 myapp_db 中
GRANT USAGE ON SCHEMA public TO myapp_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myapp_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO myapp_user;
```
這些權限的目的：
* 讓 myapp_user 可以對所有表格做 CRUD 操作
* 未來新建的表格也會自動繼承這些權限

---

# 安裝完成後，系統中新增的檔案

## 1. pgBouncer 相關檔案
檔案路徑 | 目的 | 重要內容
--------|------|--------
/usr/local/pgbouncer/bin/pgbouncer|pgBouncer 執行檔	主程式
/usr/local/pgbouncer/lib/|函式庫|相依的動態函式庫
/etc/pgbouncer/pgbouncer.ini|主設定檔|監聽埠、連線池設定、資料庫映射
/etc/pgbouncer/userlist.txt|使用者認證檔|管理員和客戶端的帳號密碼
/var/log/pgbouncer/pgbouncer.log|日誌檔	pgBouncer|運行日誌
/var/run/pgbouncer/pgbouncer.pid|PID 檔案|記錄 pgBouncer 程序 ID
/etc/systemd/system/pgbouncer.service|systemd 服務檔|服務管理設定

## 2. pgbouncer.ini 的重要設定
```conf
[databases]
myapp_db = host=localhost port=5432 dbname=myapp_db

[pgbouncer]
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
```

## 3. userlist.txt 的內容
```
"pgbouncer_admin" "admin_password"      # 管理介面用
"myapp_user" "user_password"             # 應用程式用
```

---

# 應用程式如何連線？

## 原本直接連 PostgreSQL：
```
應用程式 -> PostgreSQL (5432)
```
## 安裝 pgBouncer 後：
```
應用程式 -> pgBouncer (6432) -> PostgreSQL (5432)
```
## 應用程式的連線字串要改成：
```
# 原本
postgresql://myapp_user:password@localhost:5432/myapp_db

# 改成
postgresql://myapp_user:password@localhost:6432/myapp_db
```

---

# pgBouncer 管理介面
```sh
# 連線到 pgBouncer 管理介面
psql -h 127.0.0.1 -p 6432 -U pgbouncer_admin -d pgbouncer

# 常用管理指令
SHOW HELP;           # 顯示所有指令
SHOW POOLS;          # 顯示連線池狀態
SHOW STATS;          # 顯示統計資訊
SHOW CLIENTS;        # 顯示客戶端連線
SHOW SERVERS;        # 顯示伺服器端連線
SHOW VERSION;        # 顯示版本
PAUSE;               # 暫停池子
RESUME;              # 恢復池子
KILL <db>;           # 中斷所有連線
```

---

## **授權條款**

本專案採用 **GNU General Public License v3.0** 授權。

### **授權摘要**

這是一個自由軟體授權條款，您享有以下權利：

#### **使用權利**
- ✅ **商業使用**：可用於商業目的
- ✅ **修改**：可以修改軟體
- ✅ **散布**：可以散布軟體
- ✅ **私人使用**：可以私人使用
- ✅ **專利使用**：提供專明使用權

#### **條件與限制**
- ⚠️ **必須包含授權聲明**：散布時必須包含原始授權聲明
- ⚠️ **必須公開原始碼**：修改後散布時必須公開原始碼
- ⚠️ **相同授權**：修改後的軟體必須使用相同授權
- ⚠️ **包含變更聲明**：必須說明對原始軟體的變更

#### **責任**
- ❌ **無擔保**：軟體按現狀提供，無任何擔保
- ❌ **免責**：作者不承擔任何法律責任

### **完整授權條款**

完整的 GNU General Public License v3.0 條款請參考專案根目錄下的 `LICENSE` 檔案。

### **貢獻指南**

當您對此專案做出貢獻時：
1. 您的貢獻將採用相同的 GPL v3.0 授權
2. 您保留對您貢獻內容的版權
3. 您同意您的貢獻被專案使用和散布

### **商業使用注意事項**

雖然 GPL v3.0 允許商業使用，但需注意：
- 修改後的版本如果散布，必須公開原始碼
- 不能將此軟體整合到專有軟體中而不公開原始碼
- 建議在商業使用前諮詢法律專家

---

**© 2026 pgBouncer 自動化安裝腳本專案**  
**根據 GNU General Public License v3.0 授權**