#!/bin/bash
# scripts/manage/show-connection.sh - 顯示資料庫連線資訊
# 功能：顯示如何連線到 pgBouncer 和 PostgreSQL，包含各種客戶端的連線字串

set -e

# 取得腳本所在目錄的上一層的上一層（專案根目錄）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# 載入共用函式庫（含顏色輸出、環境變數載入等）
source "${SCRIPT_DIR}/scripts/utils/common.sh"

# 載入 .env 中的環境變數
load_env

# 顯示標題
print_header "資料庫連線資訊"

# 取得本機 IP 或主機名稱
HOSTNAME=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📍 基本連線資訊${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}資料庫名稱:${NC}     ${APP_DB_NAME}"
echo -e "  ${YELLOW}客戶端角色:${NC}     ${CLIENT_ROLE}"
echo -e "  ${YELLOW}客戶端密碼:${NC}     ${CLIENT_PASSWORD}"
echo -e "  ${YELLOW}pgBouncer 位址:${NC} ${HOSTNAME}:${PGBOUNCER_PORT}"
echo -e "  ${YELLOW}連線模式:${NC}     透過 pgBouncer (連線池)"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔌 使用 psql 連線${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}# 連線到 pgBouncer（推薦）${NC}"
echo -e "  ${GREEN}psql -h ${HOSTNAME} -p ${PGBOUNCER_PORT} -U ${CLIENT_ROLE} -d ${APP_DB_NAME}${NC}"
echo ""
echo -e "  ${CYAN}# 或輸入密碼方式${NC}"
echo -e "  ${GREEN}PGPASSWORD='${CLIENT_PASSWORD}' psql -h ${HOSTNAME} -p ${PGBOUNCER_PORT} -U ${CLIENT_ROLE} -d ${APP_DB_NAME}${NC}"
echo ""
echo -e "  ${CYAN}# 直接連線到 PostgreSQL（不使用連線池）${NC}"
echo -e "  ${YELLOW}psql -h localhost -p ${PG_PORT} -U ${CLIENT_ROLE} -d ${APP_DB_NAME}${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌐 .NET Core 連線字串${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}# appsettings.json${NC}"
echo -e "  ${GREEN}\"ConnectionStrings\": {${NC}"
echo -e "  ${GREEN}  \"Main\": \"Host=${HOSTNAME};Port=${PGBOUNCER_PORT};Database=${APP_DB_NAME};Username=${CLIENT_ROLE};Password=${CLIENT_PASSWORD};Pooling=true;MinPoolSize=1;MaxPoolSize=20;Timeout=15;CommandTimeout=30;SSL Mode=Prefer;Trust Server Certificate=true\"${NC}"
echo -e "  ${GREEN}}${NC}"
echo ""
echo -e "  ${CYAN}# Program.cs (使用 Npgsql)${NC}"
echo -e "  ${GREEN}builder.Services.AddDbContext<AppDbContext>(options =>${NC}"
echo -e "  ${GREEN}    options.UseNpgsql(builder.Configuration.GetConnectionString(\"Main\")));${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔧 其他語言連線字串${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}# Python (psycopg2)${NC}"
echo -e "  ${GREEN}conn_str = \"postgresql://${CLIENT_ROLE}:${CLIENT_PASSWORD}@${HOSTNAME}:${PGBOUNCER_PORT}/${APP_DB_NAME}\"${NC}"
echo ""
echo -e "  ${CYAN}# Node.js (pg)${NC}"
echo -e "  ${GREEN}const pool = new Pool({${NC}"
echo -e "  ${GREEN}  host: '${HOSTNAME}',${NC}"
echo -e "  ${GREEN}  port: ${PGBOUNCER_PORT},${NC}"
echo -e "  ${GREEN}  database: '${APP_DB_NAME}',${NC}"
echo -e "  ${GREEN}  user: '${CLIENT_ROLE}',${NC}"
echo -e "  ${GREEN}  password: '${CLIENT_PASSWORD}',${NC}"
echo -e "  ${GREEN}});${NC}"
echo ""
echo -e "  ${CYAN}# Go (pgx)${NC}"
echo -e "  ${GREEN}connStr := \"postgres://${CLIENT_ROLE}:${CLIENT_PASSWORD}@${HOSTNAME}:${PGBOUNCER_PORT}/${APP_DB_NAME}?sslmode=prefer\"${NC}"
echo ""
echo -e "  ${CYAN}# Java (JDBC)${NC}"
echo -e "  ${GREEN}jdbc:postgresql://${HOSTNAME}:${PGBOUNCER_PORT}/${APP_DB_NAME}?user=${CLIENT_ROLE}&password=${CLIENT_PASSWORD}${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📋 連線摘要${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Host:${NC}       ${HOSTNAME}"
echo -e "  ${YELLOW}Port:${NC}       ${PGBOUNCER_PORT}"
echo -e "  ${YELLOW}Database:${NC}   ${APP_DB_NAME}"
echo -e "  ${YELLOW}Username:${NC}   ${CLIENT_ROLE}"
echo -e "  ${YELLOW}Password:${NC}   ${CLIENT_PASSWORD}"
echo ""
echo -e "  ${CYAN}✅ 應用程式應該連線到 pgBouncer（Port ${PGBOUNCER_PORT}）而非直接連 PostgreSQL（Port ${PG_PORT}）${NC}"
echo ""
