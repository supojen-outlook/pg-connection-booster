#!/bin/bash
# scripts/install/02-install-dependencies.sh - 安裝相依套件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"

load_env

print_step "2" "安裝編譯相依套件"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

case $OS in
    ubuntu|debian)
        print_info "偵測到作業系統: Ubuntu/Debian"
        apt update
        apt install -y \
            build-essential \
            libevent-dev \
            libssl-dev \
            wget \
            tar \
            make \
            gcc \
            libc-ares-dev
        ;;
    rocky|centos|rhel|fedora)
        print_info "偵測到作業系統: RHEL/CentOS/Rocky"
        yum install -y \
            gcc \
            make \
            libevent-devel \
            openssl-devel \
            wget \
            tar \
            c-ares-devel
        ;;
    *)
        print_error "不支援的作業系統: $OS"
        exit 1
        ;;
esac

print_success "所有相依套件安裝完成"