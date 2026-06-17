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

echo "=== Step 1: Fix Boot Delay ==="
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

echo "=== Step 2: Applying IP Configuration ==="
ip addr flush dev $IFACE 2>/dev/null
ip addr add $IP dev $IFACE
ip link set dev $IFACE up

echo "=== Step 3: Setting Default Route ==="
ip route del default 2>/dev/null
ip route add default via $GATEWAY

echo "=== Step 4: Setting DNS ==="
echo "nameserver $DNS" > /etc/resolv.conf

echo "=== Step 5: Making Persistent via /etc/network/interfaces ==="
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
echo "  IP:      10.10.1.5/24"
echo "  Gateway: 10.10.1.1"
echo "  DNS:     8.8.8.8"
echo "  Boot delay: Fixed"
echo "====================================================================="
EOF

chmod +x /home/student/setup_it_node.sh
sudo /home/student/setup_it_node.sh
