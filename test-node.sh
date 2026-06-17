cat << 'EOF' > /home/student/setup_test_node.sh
#!/bin/bash
# =====================================================================
# TEST-NODE NETWORK SETUP SCRIPT
# Usage: sudo ./setup_test_node.sh
# =====================================================================

IFACE="ens3"
IP="192.168.10.20/24"
GATEWAY="192.168.10.1"
DNS="8.8.8.8"

echo "=== Step 1: Hostname ==="
hostnamectl set-hostname test-node
sed -i '/test-node/d' /etc/hosts
echo "127.0.0.1 test-node" >> /etc/hosts

echo "=== Step 2: Fix Boot Delay ==="
systemctl disable systemd-networkd-wait-online.service
systemctl mask systemd-networkd-wait-online.service
if [ -d /etc/cloud ]; then
    touch /etc/cloud/cloud-init.disabled
    systemctl disable cloud-init 2>/dev/null
    systemctl disable cloud-init-local 2>/dev/null
    systemctl disable cloud-config 2>/dev/null
    systemctl disable cloud-final 2>/dev/null
fi
sed -i 's/GRUB_TIMEOUT=.[0-9]*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub

echo "=== Step 3: Applying IP Configuration ==="
ip addr flush dev $IFACE 2>/dev/null
ip addr add $IP dev $IFACE
ip link set dev $IFACE up

echo "=== Step 4: Setting Default Route ==="
ip route del default 2>/dev/null
ip route add default via $GATEWAY

echo "=== Step 5: Setting DNS ==="
echo "nameserver $DNS" > /etc/resolv.conf

echo "=== Step 6: Making Persistent via /etc/network/interfaces ==="
cat << 'INNER' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
    address 192.168.10.20
    netmask 255.255.255.0
    gateway 192.168.10.1
    dns-nameservers 8.8.8.8
INNER

echo "=== Verifying ==="
ip addr show dev $IFACE
ip route show
ping -c 1 -W 2 192.168.10.1 && echo "Gateway: OK" || echo "Gateway: FAIL"
ping -c 1 -W 2 8.8.8.8      && echo "Internet: OK" || echo "Internet: FAIL"
ping -c 1 -W 2 google.com   && echo "DNS: OK" || echo "DNS: FAIL"

echo "====================================================================="
echo "SUCCESS: test-node configured!"
echo "  Hostname:   test-node"
echo "  IP:         192.168.10.20/24"
echo "  Gateway:    192.168.10.1"
echo "  DNS:        8.8.8.8"
echo "  Boot delay: Fixed"
echo "====================================================================="
EOF

chmod +x /home/student/setup_test_node.sh
sudo /home/student/setup_test_node.sh
