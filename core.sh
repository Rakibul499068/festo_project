#!/bin/bash
# =====================================================================
# OT-CORE SWITCH DEPLOYMENT SCRIPT
# Inter-VLAN routing via OVS + NAT for internet access
# Usage: sudo ./setup_ot_switch.sh
# =====================================================================

BRIDGE_PREFIX="br-vlan"
UPLINK="ens3"
UPLINK_IP="172.16.0.2/24"
GATEWAY="172.16.0.1"
DNS="8.8.8.8"

declare -A VLAN_PORT=( [10]="ens4" [20]="ens5" [30]="ens6" [40]="ens7" [50]="ens8" [60]="ens9" )
declare -A VLAN_GW=( [10]="172.16.10.1" [20]="172.16.20.1" [30]="172.16.30.1" [40]="172.16.40.1" [50]="172.16.50.1" [60]="172.16.60.1" )

reset() {
    echo "=== Resetting OT-Core ==="
    for vlan in 10 20 30 40 50 60; do
        ip link set dev ${BRIDGE_PREFIX}${vlan} down 2>/dev/null
        ovs-vsctl del-br ${BRIDGE_PREFIX}${vlan} 2>/dev/null
    done
    for iface in ens3 ens4 ens5 ens6 ens7 ens8 ens9; do
        ip addr flush dev $iface 2>/dev/null
        ip link set dev $iface down 2>/dev/null
    done
    iptables -t nat -F 2>/dev/null
    echo "=== Reset complete ==="
}

setup() {
    echo "=== Setting up OT-Core ==="
    reset

    echo "=== Step 1: Hostname ==="
    hostnamectl set-hostname OT-Switch
    sed -i '/OT-Switch/d' /etc/hosts
    echo "127.0.0.1 OT-Switch" >> /etc/hosts

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

    echo "=== Step 3: Enable IP Forwarding ==="
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ot-switch.conf

    echo "=== Step 4: Setup Uplink ==="
    ip addr flush dev $UPLINK 2>/dev/null
    ip link set dev $UPLINK up
    ip addr add $UPLINK_IP dev $UPLINK
    ip route del default 2>/dev/null
    ip route add default via $GATEWAY

    echo "=== Step 5: Setup DNS ==="
    echo "nameserver $DNS" > /etc/resolv.conf

    echo "=== Step 6: Setup VLAN Bridges ==="
    for vlan in 10 20 30 40 50 60; do
        port=${VLAN_PORT[$vlan]}
        gw=${VLAN_GW[$vlan]}
        bridge="${BRIDGE_PREFIX}${vlan}"
        echo "Setting up VLAN$vlan → $port → $bridge ($gw/24)"
        ovs-vsctl add-br $bridge
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port up
        ovs-vsctl add-port $bridge $port
        ip link set dev $bridge up
        ip addr add $gw/24 dev $bridge
    done

    echo "=== Step 7: NAT Masquerade for All Stations ==="
    iptables -t nat -A POSTROUTING -o $UPLINK -j MASQUERADE

    # Register with systemd only on first run
    if [ ! -f /etc/systemd/system/ot-switch.service ]; then
        echo "=== Step 8: Registering Systemd Service ==="
        printf '[Unit]\nDescription=OT-Core Switch\nAfter=openvswitch-switch.service network-online.target\nWants=openvswitch-switch.service\n\n[Service]\nType=oneshot\nExecStart=/home/student/setup_ot_switch.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/ot-switch.service
        systemctl daemon-reload
        systemctl enable ot-switch.service
        echo "Service registered."
    fi

    echo "====================================================================="
    echo "SUCCESS: OT-Core deployed!"
    echo "  Hostname:   OT-Switch"
    echo "  Boot delay: Fixed"
    echo "  Uplink:     ens3 → 172.16.0.2/24 (FW-OT)"
    echo "  DNS:        8.8.8.8"
    echo "  VLAN10:     ens4 → 172.16.10.1/24 (Station-1)"
    echo "  VLAN20:     ens5 → 172.16.20.1/24 (Station-2)"
    echo "  VLAN30:     ens6 → 172.16.30.1/24 (Station-3)"
    echo "  VLAN40:     ens7 → 172.16.40.1/24 (Station-4)"
    echo "  VLAN50:     ens8 → 172.16.50.1/24 (Station-5)"
    echo "  VLAN60:     ens9 → 172.16.60.1/24 (Station-6)"
    echo "  NAT:        Enabled on $UPLINK"
    echo ""
    echo "Useful commands:"
    echo "  Check bridges: ovs-vsctl show"
    echo "  Check routes:  ip route show"
    echo "  Check NAT:     iptables -t nat -L"
    echo "  Reset:         systemctl restart ot-switch.service"
    echo "====================================================================="
}

case "$1" in
    reset)  reset ;;
    *)      setup ;;
esac
