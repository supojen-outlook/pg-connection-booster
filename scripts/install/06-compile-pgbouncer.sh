#!/bin/bash
# scripts/install/06-compile-pgbouncer.sh - 編譯安裝 pgBouncer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "6" "編譯安裝 pgBouncer $PGBOUNCER_VERSION"

SOURCE_DIR="${PGBOUNCER_SOURCE_DIR}/pgbouncer-${PGBOUNCER_VERSION}"
SOURCE_FILE="${PGBOUNCER_SOURCE_DIR}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz"

# 檢查是否已安裝
if [ -f "${PGBOUNCER_PREFIX}/bin/pgbouncer" ]; then
    INSTALLED_VERSION=$("${PGBOUNCER_PREFIX}/bin/pgbouncer" -V 2>&1 | head -1 | grep -oP 'pgbouncer \K[0-9.]+' || echo "unknown")
    if [ "$INSTALLED_VERSION" = "$PGBOUNCER_VERSION" ]; then
        print_warning "pgBouncer $PGBOUNCER_VERSION 已安裝，跳過編譯"
        exit 0
    fi
fi

# 解壓縮
print_info "解壓縮原始碼"
if [ -d "$SOURCE_DIR" ]; then
    rm -rf "$SOURCE_DIR"
fi
tar -xzf "$SOURCE_FILE" -C "$PGBOUNCER_SOURCE_DIR"
print_success "解壓完成"

# 編譯
cd "$SOURCE_DIR"

print_info "執行 configure"
./configure --prefix="$PGBOUNCER_PREFIX" --with-openssl

print_info "編譯中 (使用 $(nproc) 個核心)"
make -j$(nproc)

print_info "安裝中"
make install

print_success "編譯安裝完成"

# 驗證安裝
if [ -f "${PGBOUNCER_PREFIX}/bin/pgbouncer" ]; then
    INSTALLED_VERSION=$("${PGBOUNCER_PREFIX}/bin/pgbouncer" -V 2>&1 | head -1)
    print_success "pgBouncer 版本: $INSTALLED_VERSION"
else
    print_error "安裝失敗"
    exit 1
fi