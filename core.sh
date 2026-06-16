cat << 'EOF' > setup_core.sh
#!/bin/bash

echo "=== Cleaning Up Previous Configs & Services ==="
systemctl stop core.service 2>/dev/null
systemctl disable core.service 2>/dev/null
rm -f /etc/systemd/system/core.service
rm -f /usr/local/bin/core.sh
systemctl daemon-reload

# 1. Create the smart, dynamic startup script
cat << 'INNER' > /usr/local/bin/core.sh
#!/bin/bash
sleep 2

echo "=== Setting up Core Switch ==="
ovs-vsctl del-br br-core 2>/dev/null
ovs-vsctl add-br br-core

# Automatically discover all real interfaces (ignoring loops, bridges, and ovs internals)
interfaces=$(ip -br link show | awk '{print $1}' | grep -E '^(ens|eth)' | sort)

# Convert list to an array
iface_array=($interfaces)

# The very first discovered interface is assumed to be your uplink (eth0 or ens3)
uplink=${iface_array[0]}

echo "Found uplink interface: $uplink"
ip addr flush dev $uplink 2>/dev/null
ip addr add 192.168.100.2/30 dev $uplink
ip link set dev $uplink up

# Map the remaining station ports dynamically to their VLAN tags
# index 1 -> tag 10, index 2 -> tag 11, etc.
vlan_tags=(10 11 12 20 21 30)
tag_index=0

for ((i=1; i<${#iface_array[@]}; i++)); do
    port=${iface_array[$i]}
    tag=${vlan_tags[$tag_index]}
    
    # If we run out of defined VLAN tags, break out
    if [ -z "$tag" ]; then break; fi
    
    ip link set dev $port up 2>/dev/null
    ovs-vsctl add-port br-core $port tag=$tag 2>/dev/null
    echo "Attached physical port $port to VLAN $tag"
    
    ((tag_index++))
done

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
ip route add default via 192.168.100.1 dev $uplink
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

echo "=== DONE: Core setup is clean and permanent via core.service! ==="
EOF

chmod +x setup_core.sh
sudo ./setup_core.sh
