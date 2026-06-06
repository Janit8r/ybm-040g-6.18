#!/bin/bash
# 添加到编译脚本 - DNS稳定性优化

echo "========================================="
echo "集成 DNS 稳定性优化"
echo "========================================="

# 创建UCI默认配置
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-dns-stability << 'EOF'
#!/bin/sh
# DNS稳定性默认配置

# 扩大DNS缓存
uci set dhcp.@dnsmasq[0].cachesize='10000'
uci set dhcp.@dnsmasq[0].min_cache_ttl='3600'
uci set dhcp.@dnsmasq[0].max_cache_ttl='86400'
uci set dhcp.@dnsmasq[0].noresolv='0'
uci set dhcp.@dnsmasq[0].sequential_ip='1'

# DNS查询优化
uci set dhcp.@dnsmasq[0].localservice='0'
uci set dhcp.@dnsmasq[0].nonwildcard='1'

uci commit dhcp

# 扩展sysctl配置
cat >> /etc/sysctl.d/99-singbox-dns.conf << 'SYSCTL'

# DNS稳定性优化
net.netfilter.nf_conntrack_udp_timeout=180
net.netfilter.nf_conntrack_udp_timeout_stream=180
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384

# 防止DNS超时
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
SYSCTL

sysctl -p /etc/sysctl.d/99-singbox-dns.conf

exit 0
EOF

chmod +x files/etc/uci-defaults/99-dns-stability

# 添加备用DNS到默认配置
cat > files/etc/resolv.conf.fallback << 'EOF'
# 备用DNS服务器
nameserver 223.5.5.5
nameserver 114.114.114.114
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

echo "✓ DNS稳定性优化已集成到编译"
echo ""
echo "优化内容："
echo "  • DNS缓存扩展到10000条"
echo "  • 缓存TTL: 1小时-24小时"
echo "  • UDP超时优化"
echo "  • 备用DNS服务器"
echo ""
