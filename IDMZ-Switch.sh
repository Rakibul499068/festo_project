cat << 'EOF' > /home/student/setup_idmz_switch.sh
#!/bin/bash
# =====================================================================
# IDMZ-SWITCH DEPLOYMENT SCRIPT
# Usage: sudo ./setup_idmz_switch.sh
# =====================================================================

BRIDGE="br-idmz"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"
INIT_SCRIPT="/home/student/idmz_switch_init.sh"
SERVICE_FILE="/etc/systemd/system/idmz-switch.service"

echo "=== Step 1: Hostname ==="
hostnamectl set-hostname IDMZ-Switch
sed -i '/IDMZ-Switch/d' /etc/hosts
echo "127.0.0.1 IDMZ-Switch" >> /etc/hosts

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

echo "=== Step 3: Creating Init Script ==="
cat << 'INNER' > $INIT_SCRIPT
#!/bin/bash

BRIDGE="br-idmz"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"

reset_switch() {
    echo "=== Resetting IDMZ-Switch ==="
    ip link set dev $BRIDGE down 2>/dev/null
    ovs-vsctl del-br $BRIDGE 2>/dev/null
    for port in $PORTS; do
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port down 2>/dev/null
    done
    echo "=== Reset complete ==="
}

setup_switch() {
    echo "=== Setting up IDMZ-Switch ==="
    reset_switch
    ovs-vsctl add-br $BRIDGE
    for port in $PORTS; do
        echo "Adding port: $port"
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port up
        ovs-vsctl add-port $BRIDGE $port 2>/dev/null
    done
    ip link set dev $BRIDGE up
    echo "=== IDMZ-Switch ready ==="
    ovs-vsctl show
}

case "$1" in
    reset)  reset_switch ;;
    *)      setup_switch ;;
esac
INNER

chmod +x $INIT_SCRIPT

echo "=== Step 4: Creating Systemd Service ==="
cat << 'INNER' > $SERVICE_FILE
[Unit]
Description=IDMZ-Switch Layer 2 Bridging Daemon
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/home/student/idmz_switch_init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

echo "=== Step 5: Enabling & Starting Service ==="
systemctl daemon-reload
systemctl enable idmz-switch.service
systemctl restart idmz-switch.service

echo "====================================================================="
echo "SUCCESS: IDMZ-Switch deployed!"
echo "  Hostname:   IDMZ-Switch"
echo "  Boot delay: Fixed"
echo "  Bridge:     br-idmz (ens3-ens11, no IP)"
echo ""
echo "Useful commands:"
echo "  Check bridge:  ovs-vsctl show"
echo "  Reset switch:  /home/student/idmz_switch_init.sh reset"
echo "  Restart svc:   systemctl restart idmz-switch.service"
echo "====================================================================="
EOF

chmod +x /home/student/setup_idmz_switch.sh
sudo /home/student/setup_idmz_switch.sh
