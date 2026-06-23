#!/bin/bash
# =====================================================================
# IDMZ-SWITCH DEPLOYMENT SCRIPT
# e0(ens3) → IDMZ-Router, e1(ens4) → MES, e2(ens5) → Historian
# Usage: sudo ./setup_idmz_switch.sh
# =====================================================================

BRIDGE="br-idmz"
PORTS="ens3 ens4 ens5 ens6 ens7 ens8 ens9 ens10 ens11"

reset() {
    echo "=== Resetting IDMZ-Switch ==="
    ip link set dev $BRIDGE down 2>/dev/null
    ovs-vsctl del-br $BRIDGE 2>/dev/null
    for port in $PORTS; do
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port down 2>/dev/null
    done
    echo "=== Reset complete ==="
}

setup() {
    echo "=== Setting up IDMZ-Switch ==="
    reset

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

    echo "=== Step 3: Setting up OVS Bridge ==="
    ovs-vsctl add-br $BRIDGE
    for port in $PORTS; do
        echo "Adding port: $port"
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port up
        ovs-vsctl add-port $BRIDGE $port 2>/dev/null
    done
    ip link set dev $BRIDGE up

    if [ ! -f /etc/systemd/system/idmz-switch.service ]; then
        echo "=== Registering Systemd Service ==="
        printf '[Unit]\nDescription=IDMZ-Switch Layer 2 Bridging Daemon\nAfter=openvswitch-switch.service network-online.target\nWants=openvswitch-switch.service\n\n[Service]\nType=oneshot\nExecStart=/home/student/setup_idmz_switch.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/idmz-switch.service
        systemctl daemon-reload
        systemctl enable idmz-switch.service
        echo "Service registered."
    fi

    echo "====================================================================="
    echo "SUCCESS: IDMZ-Switch deployed!"
    echo "  Hostname:   IDMZ-Switch"
    echo "  Boot delay: Fixed"
    echo "  Bridge:     br-idmz (ens3-ens11, no IP)"
    echo "  e0(ens3):   → IDMZ-Router"
    echo "  e1(ens4):   → MES"
    echo "  e2(ens5):   → Historian"
    echo ""
    echo "Useful commands:"
    echo "  Check bridge:  ovs-vsctl show"
    echo "  Reset:         systemctl restart idmz-switch.service"
    echo "====================================================================="
}

case "$1" in
    reset)  reset ;;
    *)      setup ;;
esac
