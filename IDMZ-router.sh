#!/bin/bash
# =====================================================================
# IDMZ-ROUTER DEPLOYMENT SCRIPT
# WAN1(ens3) → FW-IT, WAN2(ens4) → FW-OT, LAN(ens7) → IDMZ-Switch
# Usage: sudo ./setup_idmz_router.sh
# =====================================================================

WAN1="ens3"
WAN2="ens4"
LAN="ens7"
WAN1_IP="10.10.1.50/24"
WAN2_IP="172.16.0.3/24"
LAN_IP="192.168.10.1/24"
WAN1_GW="10.10.1.1"
WAN2_GW="172.16.0.1"
DNS="8.8.8.8"

reset() {
    echo "=== Resetting IDMZ-Router ==="
    ip addr flush dev $WAN1 2>/dev/null
    ip addr flush dev $WAN2 2>/dev/null
    ip addr flush dev $LAN 2>/dev/null
    ip route flush table main 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -F 2>/dev/null
    # Remove old OVS bridge if exists
    ovs-vsctl del-br br-idmz 2>/dev/null
    echo "=== Reset complete ==="
}

setup() {
    echo "=== Setting up IDMZ-Router ==="
    reset

    echo "=== Step 1: Hostname ==="
    hostnamectl set-hostname IDMZ-Router
    sed -i '/IDMZ-Router/d' /etc/hosts
    echo "127.0.0.1 IDMZ-Router" >> /etc/hosts

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
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-idmz-router.conf

    echo "=== Step 4: Setup Interfaces ==="
    # WAN1 → FW-IT
    ip link set dev $WAN1 up
    ip addr add $WAN1_IP dev $WAN1

    # WAN2 → FW-OT
    ip link set dev $WAN2 up
    ip addr add $WAN2_IP dev $WAN2

    # LAN → IDMZ-Switch
    ip link set dev $LAN up
    ip addr add $LAN_IP dev $LAN

    echo "=== Step 5: Setup Routing ==="
    # Default route via FW-IT (IT side)
    ip route add default via $WAN1_GW

    # Route OT subnets via FW-OT
    ip route add 172.16.10.0/24 via $WAN2_GW
    ip route add 172.16.20.0/24 via $WAN2_GW
    ip route add 172.16.30.0/24 via $WAN2_GW
    ip route add 172.16.40.0/24 via $WAN2_GW
    ip route add 172.16.50.0/24 via $WAN2_GW
    ip route add 172.16.60.0/24 via $WAN2_GW
    ip route add 172.16.0.0/24 via $WAN2_GW

    # Route IT subnet via FW-IT
    ip route add 10.10.1.0/24 via $WAN1_GW

    echo "=== Step 6: Setup DNS ==="
    echo "nameserver $DNS" > /etc/resolv.conf

    echo "=== Step 7: Setup NAT ==="
    # NAT for IDMZ devices going to IT zone
    iptables -t nat -A POSTROUTING -o $WAN1 -j MASQUERADE
    # NAT for IDMZ devices going to OT zone
    iptables -t nat -A POSTROUTING -o $WAN2 -j MASQUERADE

    echo "=== Step 8: Firewall Rules ==="
    # Allow established connections
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    # Allow IDMZ → IT
    iptables -A FORWARD -i $LAN -o $WAN1 -j ACCEPT
    # Allow IDMZ → OT
    iptables -A FORWARD -i $LAN -o $WAN2 -j ACCEPT
    # Allow IT → IDMZ
    iptables -A FORWARD -i $WAN1 -o $LAN -j ACCEPT
    # Allow OT → IDMZ
    iptables -A FORWARD -i $WAN2 -o $LAN -j ACCEPT
    # Block IT → OT directly
    iptables -A FORWARD -i $WAN1 -o $WAN2 -j DROP
    # Block OT → IT directly
    iptables -A FORWARD -i $WAN2 -o $WAN1 -j DROP

    if [ ! -f /etc/systemd/system/idmz-router.service ]; then
        echo "=== Registering Systemd Service ==="
        printf '[Unit]\nDescription=IDMZ-Router Service\nAfter=network-online.target\nWants=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/home/student/setup_idmz_router.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/idmz-router.service
        systemctl daemon-reload
        systemctl enable idmz-router.service
        echo "Service registered."
    fi

    echo "====================================================================="
    echo "SUCCESS: IDMZ-Router deployed!"
    echo "  Hostname:   IDMZ-Router"
    echo "  Boot delay: Fixed"
    echo "  WAN1:       ens3 → 10.10.1.50/24 (FW-IT)"
    echo "  WAN2:       ens4 → 172.16.0.3/24 (FW-OT)"
    echo "  LAN:        ens7 → 192.168.10.1/24 (IDMZ-Switch)"
    echo "  Firewall:   IT↔OT blocked, IDMZ↔IT allowed, IDMZ↔OT allowed"
    echo ""
    echo "Useful commands:"
    echo "  Check routes:    ip route show"
    echo "  Check firewall:  iptables -L"
    echo "  Check NAT:       iptables -t nat -L"
    echo "  Reset:           systemctl restart idmz-router.service"
    echo "====================================================================="
}

case "$1" in
    reset)  reset ;;
    *)      setup ;;
esac
