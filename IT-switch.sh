cat << 'EOF' > /home/student/setup_it_smart_switch.sh
#!/bin/bash
# =====================================================================
# IT-SWITCH DEPLOYMENT SCRIPT
# Run this to deploy or redeploy the IT-Switch configuration
# Usage: sudo ./setup_it_smart_switch.sh
# =====================================================================

BRIDGE="br-it"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"
INIT_SCRIPT="/home/student/it_switch_init.sh"
SERVICE_FILE="/etc/systemd/system/it-switch.service"

echo "=== Step 1: Creating Init Script ==="
cat << 'INNER' > $INIT_SCRIPT
#!/bin/bash

BRIDGE="br-it"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"

reset_switch() {
    echo "=== Resetting IT-Switch ==="
    ip link set dev $BRIDGE down 2>/dev/null
    ovs-vsctl del-br $BRIDGE 2>/dev/null
    for port in $PORTS; do
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port down 2>/dev/null
    done
    echo "=== Reset complete ==="
}

setup_switch() {
    echo "=== Setting up IT-Switch ==="

    # Clean slate
    reset_switch

    # Create fresh OVS bridge
    ovs-vsctl add-br $BRIDGE

    # Add all ports
    for port in $PORTS; do
        echo "Adding port: $port"
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port up
        ovs-vsctl add-port $BRIDGE $port 2>/dev/null
    done

    # Bring up bridge with NO IP (pure L2)
    ip link set dev $BRIDGE up

    echo "=== IT-Switch ready ==="
    ovs-vsctl show
}

case "$1" in
    reset)  reset_switch ;;
    *)      setup_switch ;;
esac
INNER

chmod +x $INIT_SCRIPT
echo "Init script created at $INIT_SCRIPT"

echo "=== Step 2: Creating Systemd Service ==="
cat << 'INNER' > $SERVICE_FILE
[Unit]
Description=IT-Switch Layer 2 Bridging Daemon
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/home/student/it_switch_init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

echo "Service file created at $SERVICE_FILE"

echo "=== Step 3: Enabling & Starting Service ==="
systemctl daemon-reload
systemctl enable it-switch.service
systemctl restart it-switch.service

echo ""
echo "====================================================================="
echo "SUCCESS: IT-Switch deployed!"
echo ""
echo "Useful commands:"
echo "  Check status:  ovs-vsctl show"
echo "  Reset switch:  /home/student/it_switch_init.sh reset"
echo "  Re-setup:      /home/student/it_switch_init.sh"
echo "  Restart svc:   systemctl restart it-switch.service"
echo "====================================================================="
EOF

chmod +x /home/student/setup_it_smart_switch.sh
sudo /home/student/setup_it_smart_switch.sh
