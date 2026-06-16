cat << 'EOF' > /home/student/setup_it_node.sh
#!/bin/bash
# =====================================================================
# IT-NODE NETWORK SETUP SCRIPT
# Usage: sudo ./setup_it_node.sh
# =====================================================================

IFACE="ens3"
IP="10.10.1.5/24"
GATEWAY="10.10.1.1"
DNS="8.8.8.8"

echo "=== Step 1: Applying IP Configuration ==="
ip addr flush dev $IFACE 2>/dev/null
ip addr add $IP dev $IFACE
ip link set dev $IFACE up

echo "=== Step 2: Setting Default Route ==="
ip route del default 2>/dev/null
ip route add default via $GATEWAY

echo "=== Step 3: Setting DNS ==="
echo "nameserver $DNS" > /etc/resolv.conf

echo "=== Step 4: Making Persistent via /etc/network/interfaces ==="
cat << 'INNER' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
    address 10.10.1.5
    netmask 255.255.255.0
    gateway 10.10.1.1
    dns-nameservers 8.8.8.8
INNER

echo "=== Verifying ==="
ip addr show dev $IFACE
ip route show
ping -c 1 10.10.1.1 && echo "Gateway: OK"
ping -c 1 8.8.8.8   && echo "Internet: OK"
ping -c 1 google.com && echo "DNS: OK"

echo "====================================================================="
echo "SUCCESS: IT-Node network configured!"
echo ""
echo "  IP:      10.10.1.5/24"
echo "  Gateway: 10.10.1.1"
echo "  DNS:     8.8.8.8"
echo "====================================================================="
EOF

chmod +x /home/student/setup_it_node.sh
sudo /home/student/setup_it_node.sh
