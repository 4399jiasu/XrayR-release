#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查是否为 root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用 root 用户运行！" && exit 1

# 检测系统类型
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -qi "debian" /etc/issue || grep -qi "debian" /proc/version; then
    release="debian"
elif grep -qi "ubuntu" /etc/issue || grep -qi "ubuntu" /proc/version; then
    release="ubuntu"
else
    echo -e "${red}无法识别系统版本，请联系脚本作者${plain}" && exit 1
fi

# 检测系统架构
arch=$(uname -m)
case "$arch" in
    x86_64|amd64) arch="64" ;;
    aarch64|arm64) arch="arm64-v8a" ;;
    s390x) arch="s390x" ;;
    *) arch="64"; echo -e "${red}未知架构，默认使用：${arch}${plain}" ;;
esac

echo -e "系统架构: ${green}${arch}${plain}"

# 安装依赖
install_base() {
    if [[ "$release" == "centos" ]]; then
        yum install -y epel-release wget curl unzip tar crontabs socat
    else
        apt update -y
        apt install -y wget curl unzip tar cron socat
    fi
}

# 安装 XrayR 主体逻辑
install_XrayR() {
    rm -rf /usr/local/XrayR
    mkdir -p /usr/local/XrayR
    cd /usr/local/XrayR

    if [[ $# -eq 0 ]]; then
        version=$(curl -sL https://api.github.com/repos/4399jiasu/XrayR/releases/latest | grep tag_name | sed -E 's/.*"([^"]+)".*/\1/')
    else
        version="$1"
        [[ "$version" != v* ]] && version="v$version"
    fi

    echo -e "正在安装版本: ${green}${version}${plain}"

    zip_file="XrayR-linux-${arch}.zip"
    download_url="https://github.com/4399jiasu/XrayR/releases/download/${version}/${zip_file}"
    wget -q -O "$zip_file" "$download_url" || {
        echo -e "${red}下载失败：${download_url}${plain}"
        exit 1
    }

    unzip -q "$zip_file"
    if [ -d "XrayR-linux-${arch}" ]; then
        mv XrayR-linux-${arch}/* .
        rm -rf XrayR-linux-${arch}
    fi
    rm -f XrayR-linux.zip

    chmod +x XrayR
    mkdir -p /etc/XrayR

    # 配置 systemd 启动服务
    wget -q -O /etc/systemd/system/XrayR.service https://raw.githubusercontent.com/4399jiasu/XrayR-release/master/XrayR.service
    systemctl daemon-reload
    systemctl enable XrayR

    cp -f geoip.dat geosite.dat /etc/XrayR/

    [[ ! -f /etc/XrayR/config.yml ]] && cp config.yml /etc/XrayR/

    # 默认文件
    for f in dns.json route.json custom_outbound.json custom_inbound.json rulelist; do
        [[ -f "$f" ]] && cp -n "$f" /etc/XrayR/
    done

    # 管理脚本
    curl -sLo /usr/bin/XrayR https://raw.githubusercontent.com/4399jiasu/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr

    echo -e "${green}XrayR 安装成功！${plain}"
    echo "使用命令：XrayR 或 xrayr 查看管理菜单"
}

echo -e "${green}开始安装依赖...${plain}"
install_base

echo -e "${green}开始安装 XrayR...${plain}"
install_XrayR "$1"
