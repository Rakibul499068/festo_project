cat << 'EOF' > setup_core.sh
#!/bin/bash

echo "=== Cleaning Up Previous Configs & Services ==="
systemctl stop core.service 2>/dev/null
systemctl disable core.service 2>/dev/null
rm -f /etc/systemd/system/core.service
rm -f /usr/local/bin/core.sh
systemctl daemon-reload

# 1. Create the explicit Core mapping script
cat << 'INNER' > /usr/local/bin/core.sh
#!/bin/bash
sleep 2

echo "=== Setting up Core Switch ==="
ovs-vsctl del-br br-core 2>/dev/null
ovs-vsctl add-br br-core

# 1. Bring up your Firewall Uplink on ens3
ip addr flush dev ens3 2>/dev/null
ip addr add 192.168.100.2/24 dev ens3
ip link set dev ens3 up

# 2. Force all active signaling ports UP
for i in {4..7}; do
    ip link set dev ens$i up 2>/dev/null
done

# 3. Explicitly map your ports to specific VLAN tags
# If your pings fail after this, we just need to swap these tag numbers below!
ovs-vsctl add-port br-core ens4 tag=10 2>/dev/null
ovs-vsctl add-port br-core ens5 tag=11 2>/dev/null
ovs-vsctl add-port br-core ens6 tag=12 2>/dev/null
ovs-vsctl add-port br-core ens7 tag=20 2>/dev/null

echo "=== Creating Virtual Routing Gateways ==="
for tag in 10 11 12 20 21 30; do
    ovs-vsctl add-port br-core vlan$tag -- set interface vlan$tag type=internal 2>/dev/null
    ovs-vsctl set port vlan$tag tag=$tag
    ip addr flush dev vlan$tag 2>/dev/null
    ip addr add 172.16.$tag.1/24 dev vlan$tag
    ip link set dev vlan$tag up
done

ip link set dev br-core up

# Routes and IP Forwarding
ip route del default 2>/dev/null
ip route add default via 192.168.100.1 dev ens3
sysctl -w net.ipv4.ip_forward=1
INNER

# 2. Make it executable
chmod +x /usr/local/bin/core.sh

# 3. Create the simple systemd service file
cat << 'INNER' > /etc/systemd/system/core.service
[Unit]
Description=Core Switch Service
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/core.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

# 4. Enable and start it permanently
systemctl daemon-reload
systemctl enable core.service
systemctl restart core.service

# 5. Save forwarding to system config
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p

echo "=== DONE: Explicit Core setup applied via core.service! ==="
EOF

chmod +x setup_core.sh
sudo ./setup_core.sh
