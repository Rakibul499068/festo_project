cat << 'EOF' > /home/student/setup_station1_switch.sh
#!/bin/bash
# =====================================================================
# STATION-1 SWITCH DEPLOYMENT SCRIPT
# e0(ens3) → OT-Core, e1(ens4) → PLC-1, e2(ens5) → HMI-1
# Usage: sudo ./setup_station1_switch.sh
# =====================================================================

BRIDGE="br-station1"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"

echo "=== Step 1: Hostname ==="
hostnamectl set-hostname Station-1-Switch
sed -i '/Station-1-Switch/d' /etc/hosts
echo "127.0.0.1 Station-1-Switch" >> /etc/hosts

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

echo "=== Step 3: Setting up OVS Bridge ==="
ip link set dev $BRIDGE down 2>/dev/null
ovs-vsctl del-br $BRIDGE 2>/dev/null
ovs-vsctl add-br $BRIDGE
for port in $PORTS; do
    echo "Adding port: $port"
    ip addr flush dev $port 2>/dev/null
    ip link set dev $port up
    ovs-vsctl add-port $BRIDGE $port 2>/dev/null
done
ip link set dev $BRIDGE up

echo "=== Step 4: Making Persistent via Systemd ==="
cat << 'INNER' > /etc/systemd/system/station1-switch.service
[Unit]
Description=Station-1-Switch Layer 2 Bridging Daemon
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/home/student/setup_station1_switch.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

systemctl daemon-reload
systemctl enable station1-switch.service

echo "====================================================================="
echo "SUCCESS: Station-1-Switch deployed!"
echo "  Hostname:   Station-1-Switch"
echo "  Boot delay: Fixed"
echo "  Bridge:     br-station1 (ens3-ens11, no IP)"
echo "  e0(ens3):   → OT-Core"
echo "  e1(ens4):   → PLC-1"
echo "  e2(ens5):   → HMI-1"
echo ""
echo "Useful commands:"
echo "  Check bridge:  ovs-vsctl show"
echo "  Reset:         systemctl restart station1-switch.service"
echo "====================================================================="
EOF

chmod +x /home/student/setup_station1_switch.sh
sudo /home/student/setup_station1_switch.sh
