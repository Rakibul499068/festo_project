#!/bin/bash
# =====================================================================
# STATION-6 SWITCH DEPLOYMENT SCRIPT
# e0(ens3) → OT-Core, e1(ens4) → PLC-6, e2(ens5) → HMI-6
# Usage: sudo ./setup_station6_switch.sh
# =====================================================================

BRIDGE="br-station6"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"

reset() {
    echo "=== Resetting Station-6-Switch ==="
    ip link set dev $BRIDGE down 2>/dev/null
    ovs-vsctl del-br $BRIDGE 2>/dev/null
    for port in $PORTS; do
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port down 2>/dev/null
    done
    echo "=== Reset complete ==="
}

setup() {
    echo "=== Setting up Station-6-Switch ==="
    reset

    echo "=== Step 1: Hostname ==="
    hostnamectl set-hostname Station-6-Switch
    sed -i '/Station-6-Switch/d' /etc/hosts
    echo "127.0.0.1 Station-6-Switch" >> /etc/hosts

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
    ovs-vsctl add-br $BRIDGE
    for port in $PORTS; do
        echo "Adding port: $port"
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port up
        ovs-vsctl add-port $BRIDGE $port 2>/dev/null
    done
    ip link set dev $BRIDGE up

    if [ ! -f /etc/systemd/system/station6-switch.service ]; then
        echo "=== Registering Systemd Service ==="
        printf '[Unit]\nDescription=Station-6-Switch Layer 2 Bridging Daemon\nAfter=openvswitch-switch.service network-online.target\nWants=openvswitch-switch.service\n\n[Service]\nType=oneshot\nExecStart=/home/student/setup_station6_switch.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/station6-switch.service
        systemctl daemon-reload
        systemctl enable station6-switch.service
        echo "Service registered."
    fi

    echo "====================================================================="
    echo "SUCCESS: Station-6-Switch deployed!"
    echo "  Hostname:   Station-6-Switch"
    echo "  Boot delay: Fixed"
    echo "  Bridge:     br-station6 (ens3-ens11, no IP)"
    echo "  e0(ens3):   → OT-Core"
    echo "  e1(ens4):   → PLC-6"
    echo "  e2(ens5):   → HMI-6"
    echo ""
    echo "Useful commands:"
    echo "  Check bridge:  ovs-vsctl show"
    echo "  Reset:         systemctl restart station6-switch.service"
    echo "====================================================================="
}

case "$1" in
    reset)  reset ;;
    *)      setup ;;
esac
