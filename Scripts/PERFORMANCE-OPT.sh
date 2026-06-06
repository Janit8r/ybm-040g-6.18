#!/bin/bash
# sing-box 性能优化 - 编译时集成

echo "========================================="
echo "集成 sing-box 性能优化"
echo "========================================="

# 创建files目录
mkdir -p files/etc/sysctl.d
mkdir -p files/etc/uci-defaults

# 1. TCP性能优化 - sysctl配置
cat > files/etc/sysctl.d/10-tcp-bbr.conf << 'EOF'
# TCP BBR拥塞控制
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP性能优化
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=3

# 缓冲区优化（代理性能）
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.core.rmem_default=1048576
net.core.wmem_default=1048576
net.ipv4.tcp_rmem=4096 1048576 33554432
net.ipv4.tcp_wmem=4096 1048576 33554432
net.ipv4.tcp_mem=786432 1048576 26777216

# 连接优化
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192

# UDP优化（DNS + YouTube QUIC）
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384

# 连接跟踪优化
net.netfilter.nf_conntrack_max=524288
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=180
EOF

# 2. 启动时优化脚本
cat > files/etc/uci-defaults/95-network-optimization << 'EOF'
#!/bin/sh
# 网络性能优化

# 应用sysctl配置
sysctl -p /etc/sysctl.d/10-tcp-bbr.conf

# 加载BBR模块
modprobe tcp_bbr 2>/dev/null

# 验证BBR
if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
    logger -t optimize "BBR已启用"
else
    logger -t optimize "BBR加载失败，使用默认cubic"
fi

# 设置MTU为1400（优化大包传输）
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|lan|wan|br-)'); do
    ip link set "$iface" mtu 1400 2>/dev/null
done

logger -t optimize "网络优化已应用"

exit 0
EOF

chmod +x files/etc/uci-defaults/95-network-optimization

# 3. YouTube QUIC优化（可选）
cat > files/etc/hotplug.d/iface/98-quic-optimize << 'EOF'
#!/bin/sh
# YouTube QUIC优化 - 如需禁用QUIC取消注释下面的规则

[ "$ACTION" = ifup ] || exit 0

case "$INTERFACE" in
    wan*)
        # 如果YouTube播放有问题，取消下面注释禁用QUIC
        # iptables -I OUTPUT -p udp --dport 443 -j REJECT 2>/dev/null
        # logger -t quic "QUIC已禁用，YouTube将使用TCP"
        ;;
esac
EOF

chmod +x files/etc/hotplug.d/iface/98-quic-optimize

# 4. DNS缓存优化（合并之前的DNS优化）
cat > files/etc/uci-defaults/99-dns-stability << 'EOF'
#!/bin/sh
# DNS + 代理综合优化

# DNS缓存扩展
uci set dhcp.@dnsmasq[0].cachesize='10000'
uci set dhcp.@dnsmasq[0].min_cache_ttl='3600'
uci set dhcp.@dnsmasq[0].max_cache_ttl='86400'
uci set dhcp.@dnsmasq[0].noresolv='0'
uci set dhcp.@dnsmasq[0].sequential_ip='1'
uci set dhcp.@dnsmasq[0].localservice='0'
uci set dhcp.@dnsmasq[0].nonwildcard='1'

# 可选：禁用IPv6 AAAA查询（提升稳定性）
# uci set dhcp.@dnsmasq[0].filter_aaaa='1'

uci commit dhcp

exit 0
EOF

chmod +x files/etc/uci-defaults/99-dns-stability

echo "✓ TCP BBR优化已集成"
echo "✓ 缓冲区扩展到32MB"
echo "✓ 连接跟踪表扩展到524288"
echo "✓ MTU优化为1400"
echo "✓ DNS缓存扩展到10000条"
echo "✓ YouTube QUIC优化已配置"
echo ""
echo "注意："
echo "  • sing-box配置需手动添加 packet_encoding 和 multiplex"
echo "  • 如YouTube有问题，编辑 /etc/hotplug.d/iface/98-quic-optimize 取消注释"
echo ""
