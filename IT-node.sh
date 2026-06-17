cat << 'EOF' > /home/student/setup_it_node.sh
#!/bin/bash
# =====================================================================
# IT-NODE NETWORK SETUP SCRIPT
# Usage: sudo ./setup_it_node.sh
# =====================================================================

IFACE="ens3"
IP="10.10.1.5/24"
GATEWAY="10.10.1.1"
DNS="10.10.1.1"

echo "=== Step 1: Hostname ==="
hostnamectl set-hostname IT-Node
sed -i '/IT-Node/d' /etc/hosts
echo "127.0.0.1 IT-Node" >> /etc/hosts

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

echo "=== Step 3: Applying Network Config ==="
ip addr flush dev $IFACE 2>/dev/null
ip addr add $IP dev $IFACE
ip link set dev $IFACE up
ip route del default 2>/dev/null
ip route add default via $GATEWAY
echo "nameserver $DNS" > /etc/resolv.conf

echo "=== Step 4: Making Network Persistent ==="
cat << 'INNER' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
    address 10.10.1.5
    netmask 255.255.255.0
    gateway 10.10.1.1
    dns-nameservers 10.10.1.1
INNER

echo "=== Step 5: Verifying ==="
ping -c 1 -W 2 10.10.1.1 && echo "Gateway:  OK" || echo "Gateway:  FAIL"
ping -c 1 -W 2 8.8.8.8   && echo "Internet: OK" || echo "Internet: FAIL"
ping -c 1 -W 2 google.com && echo "DNS:      OK" || echo "DNS:      FAIL (FW-Edge DNS may need enabling)"

echo "====================================================================="
echo "SUCCESS: IT-Node configured!"
echo "  Hostname:  IT-Node"
echo "  IP:        10.10.1.5/24"
echo "  Gateway:   10.10.1.1"
echo "  DNS:       10.10.1.1 (via FW-Edge)"
echo "  Boot delay: Fixed"
echo "====================================================================="
EOF

chmod +x /home/student/setup_it_node.sh
sudo /home/student/setup_it_node.sh
