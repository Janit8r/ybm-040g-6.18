#!/bin/bash
# 添加到 Scripts/Handles.sh 或创建为 Scripts/SINGBOX-FIX.sh

# sing-box DNS "unexpected EOF" 修复集成

echo "========================================="
echo "集成 sing-box DNS 修复"
echo "========================================="

# 创建files目录结构
mkdir -p files/etc/sysctl.d
mkdir -p files/etc/hotplug.d/iface
mkdir -p files/etc/init.d

# 1. 系统级别网络优化
cat > files/etc/sysctl.d/99-singbox-dns.conf << 'EOF'
# sing-box DNS优化 - 防止 "unexpected EOF"

# 增大网络缓冲区
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=262144
net.core.wmem_default=262144

# TCP缓冲区优化
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# UDP缓冲区优化（DNS主要使用UDP）
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# 连接跟踪优化
net.netfilter.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=7200

# 网络转发
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# TCP优化
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
EOF

# 2. MTU自动优化热插拔脚本
cat > files/etc/hotplug.d/iface/99-mtu-fix << 'EOF'
#!/bin/sh
# 防止DNS包分片导致 unexpected EOF

[ "$ACTION" = ifup ] || exit 0

case "$INTERFACE" in
    lan|wan|eth*|br-*)
        # 设置标准MTU
        ip link set "$DEVICE" mtu 1500 2>/dev/null && \
            logger -t singbox-fix "Set $DEVICE MTU=1500"
        
        # 禁用TSO/GSO（可选，如果仍有问题）
        # ethtool -K "$DEVICE" tso off gso off 2>/dev/null
    ;;
esac
EOF
chmod +x files/etc/hotplug.d/iface/99-mtu-fix

# 3. sing-box启动前优化脚本
cat > files/etc/init.d/singbox-prestart << 'EOF'
#!/bin/sh /etc/rc.common
# sing-box 启动前网络优化

START=19  # 在sing-box(20)之前运行
STOP=81   # 在sing-box(80)之后停止

start() {
    # 应用sysctl配置
    sysctl -p /etc/sysctl.d/99-singbox-dns.conf >/dev/null 2>&1
    
    # 检查并优化网口MTU
    for dev in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|lan|wan|br-)'); do
        ip link set "$dev" mtu 1500 2>/dev/null
    done
    
    logger -t singbox-fix "Network optimization applied"
}

stop() {
    :
}
EOF
chmod +x files/etc/init.d/singbox-prestart

# 4. 添加到系统启动
mkdir -p files/etc/rc.d
ln -sf ../init.d/singbox-prestart files/etc/rc.d/S19singbox-prestart 2>/dev/null

echo "✓ sing-box DNS修复已集成到编译"
echo ""
echo "修复内容："
echo "  • 网络缓冲区扩大到16MB"
echo "  • UDP缓冲区优化（DNS关键）"
echo "  • MTU自动设置为1500"
echo "  • 连接跟踪表扩展"
echo "  • sing-box启动前自动优化"
echo ""
