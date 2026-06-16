cat << 'EOF' > setup_it_smart_switch.sh
#!/bin/bash
# =====================================================================
# UNIFIED SMART SWITCH DEPLOYMENT SCRIPT (IT-SWITCH)
# =====================================================================

echo "=== Step 1: Creating Initialization Script ==="
mkdir -p /usr/local/bin

cat << 'INNER' > /usr/local/bin/it_switch_init.sh
#!/bin/bash
echo "=== Triggering Smart Switch Engine ==="

# Tear down old structural states
ip link set dev br-it down 2>/dev/null
ovs-vsctl del-br br-it 2>/dev/null

# Build modern Open vSwitch L2 Bridge
ovs-vsctl add-br br-it

# Bind target ports (eth0, eth1, eth2) seamlessly to the L2 forwarding plane
for port in eth0 eth1 eth2; do
    echo "Staging interface link: $port"
    ip addr flush dev $port 2>/dev/null
    ip link set dev $port up
    ovs-vsctl add-port br-it $port 2>/dev/null
done

# Bring up virtual software interface bridge
ip link set dev br-it up

# Assign switch control-plane interface management IP
ip addr flush dev br-it 2>/dev/null
ip addr add 10.10.1.1/24 dev br-it

# Ensure kernel tracking allows clear frame transition
sysctl -w net.ipv4.ip_forward=1
INNER

# Make the internal script executable
chmod +x /usr/local/bin/it_switch_init.sh


echo "=== Step 2: Creating Systemd Boot Service ==="
cat << 'INNER' > /etc/systemd/system/it-switch.service
[Unit]
Description=IT-Switch Smart Layer 2 Bridging Daemon Setup
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/it_switch_init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER


echo "=== Step 3: Activating & Running Architecture ==="
systemctl daemon-reload
systemctl enable it-switch.service
systemctl restart it-switch.service

echo "====================================================================="
echo "=== SUCCESS: IT-Switch is running transparently as a Smart Switch! ==="
echo "====================================================================="
EOF

# Run the master deployment file
chmod +x setup_it_smart_switch.sh
sudo ./setup_it_smart_switch.sh
