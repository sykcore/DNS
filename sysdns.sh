#!/bin/bash
# ===========================
# 脚本功能：永久修改系统 DNS
# 支持 Ubuntu / CentOS
# 作者：Chis
# ===========================

# 设置你想用的 DNS
PRIMARY_DNS="8.8.8.8"
SECONDARY_DNS="1.1.1.1"

# 检测系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
else
    echo "无法检测系统类型"
    exit 1
fi

echo "检测到系统：$OS_NAME"
echo "即将将 DNS 设置为：$PRIMARY_DNS $SECONDARY_DNS"

# --------------------------
# Ubuntu / Debian 系统
# --------------------------
if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
    # 检查 systemd-resolved 是否存在
    if systemctl list-units | grep -q resolved; then
        echo "修改 systemd-resolved 配置..."
        sudo mkdir -p /etc/systemd
        sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=$PRIMARY_DNS $SECONDARY_DNS
FallbackDNS=$SECONDARY_DNS
EOF
        sudo systemctl restart systemd-resolved
        sudo systemctl enable systemd-resolved
        echo "DNS 已永久修改并生效 (systemd-resolved)"
    else
        echo "systemd-resolved 未检测到，尝试修改 /etc/resolv.conf"
        sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver $PRIMARY_DNS
nameserver $SECONDARY_DNS
EOF
        echo "DNS 已修改为临时生效 (请确保 NetworkManager 不覆盖)"
    fi

# --------------------------
# CentOS / RHEL 系统
# --------------------------
elif [[ "$OS_NAME" == "centos" || "$OS_NAME" == "rhel" ]]; then
    # 使用 NetworkManager 修改 DNS
    echo "修改 NetworkManager 配置..."
    CONNECTION=$(nmcli -t -f NAME c show --active | head -n1)
    if [ -z "$CONNECTION" ]; then
        echo "未检测到活动网络连接，请手动设置"
        exit 1
    fi
    nmcli connection modify "$CONNECTION" ipv4.dns "$PRIMARY_DNS $SECONDARY_DNS"
    nmcli connection modify "$CONNECTION" ipv4.ignore-auto-dns yes
    nmcli connection up "$CONNECTION"
    echo "DNS 已永久修改并生效 (NetworkManager)"

else
    echo "不支持该系统，请手动修改 DNS"
    exit 1
fi

# --------------------------
# 测试 DNS 是否生效
# --------------------------
echo "测试 DNS 解析是否生效..."
dig @${PRIMARY_DNS} www.google.com +short
dig @${SECONDARY_DNS} www.google.com +short

echo "脚本执行完成 ✅"
