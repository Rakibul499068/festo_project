cat << 'EOF' > /home/student/setup_ot_switch.sh
#!/bin/bash
# =====================================================================
# OT-SWITCH DEPLOYMENT SCRIPT
# Inter-VLAN routing via OVS
# Usage: sudo ./setup_ot_switch.sh
# =====================================================================

INIT_SCRIPT="/home/student/ot_switch_init.sh"
SERVICE_FILE="/etc/systemd/system/ot-switch.service"

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

echo "=== Step 3: Creating Init Script ==="
cat << 'INNER' > $INIT_SCRIPT
#!/bin/bash

# =====================================================================
# OT-Switch interfaces:
#   ens3  → uplink to FW-OT (172.16.0.2/24)
#   ens4  → Station-1 (VLAN10 172.16.10.0/24)
#   ens5  → Station-2 (VLAN20 172.16.20.0/24)
#   ens6  → Station-3 (VLAN30 172.16.30.0/24)
#   ens7  → Station-4 (VLAN40 172.16.40.0/24)
#   ens8  → Station-5 (VLAN50 172.16.50.0/24)
#   ens9  → Station-6 (VLAN60 172.16.60.0/24)
# =====================================================================

UPLINK="ens3"
UPLINK_IP="172.16.0.2/24"
GATEWAY="172.16.0.1"

declare -A VLAN_PORT=( [10]="ens4" [20]="ens5" [30]="ens6" [40]="ens7" [50]="ens8" [60]="ens9" )
declare -A VLAN_GW=(   [10]="172.16.10.1" [20]="172.16.20.1" [30]="172.16.30.1" [40]="172.16.40.1" [50]="172.16.50.1" [60]="172.16.60.1" )

reset_switch() {
    echo "=== Resetting OT-Switch ==="
    for vlan in 10 20 30 40 50 60; do
        ip link set dev br-vlan$vlan down 2>/dev/null
        ovs-vsctl del-br br-vlan$vlan 2>/dev/null
    done
    ip link set dev br-uplink down 2>/dev/null
    ovs-vsctl del-br br-uplink 2>/dev/null
    for iface in ens3 ens4 ens5 ens6 ens7 ens8 ens9; do
        ip addr flush dev $iface 2>/dev/null
        ip link set dev $iface down 2>/dev/null
    done
    echo "=== Reset complete ==="
}

setup_switch() {
    echo "=== Setting up OT-Switch ==="
    reset_switch

    # Enable IP forwarding for inter-VLAN routing
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ot-switch.conf

    # Setup uplink to FW-OT
    echo "Setting up uplink: $UPLINK → $UPLINK_IP"
    ip link set dev $UPLINK up
    ip addr add $UPLINK_IP dev $UPLINK
    ip route add default via $GATEWAY

    # Setup one OVS bridge per VLAN
    for vlan in 10 20 30 40 50 60; do
        port=${VLAN_PORT[$vlan]}
        gw=${VLAN_GW[$vlan]}
        bridge="br-vlan$vlan"

        echo "Setting up VLAN$vlan → $port → $bridge ($gw/24)"

        # Create OVS bridge
        ovs-vsctl add-br $bridge

        # Add station port to bridge
        ip addr flush dev $port 2>/dev/null
        ip link set dev $port up
        ovs-vsctl add-port $bridge $port

        # Assign gateway IP to bridge (this is the default gateway for stations)
        ip link set dev $bridge up
        ip addr add $gw/24 dev $bridge
    done

    echo "=== OT-Switch ready ==="
    echo "--- Bridges ---"
    ovs-vsctl show
    echo "--- Routes ---"
    ip route show
}

case "$1" in
    reset)  reset_switch ;;
    *)      setup_switch ;;
esac
INNER

chmod +x $INIT_SCRIPT

echo "=== Step 4: Making IP Forward Persistent ==="
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ot-switch.conf

echo "=== Step 5: Creating Systemd Service ==="
cat << 'INNER' > $SERVICE_FILE
[Unit]
Description=OT-Switch Inter-VLAN Routing Daemon
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/home/student/ot_switch_init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

echo "=== Step 6: Enabling & Starting Service ==="
systemctl daemon-reload
systemctl enable ot-switch.service
systemctl restart ot-switch.service

echo "====================================================================="
echo "SUCCESS: OT-Switch deployed!"
echo "  Hostname:     OT-Switch"
echo "  Boot delay:   Fixed"
echo "  Uplink:       ens3 → 172.16.0.2/24 (FW-OT)"
echo "  VLAN10:       ens4 → 172.16.10.1/24 (Station-1)"
echo "  VLAN20:       ens5 → 172.16.20.1/24 (Station-2)"
echo "  VLAN30:       ens6 → 172.16.30.1/24 (Station-3)"
echo "  VLAN40:       ens7 → 172.16.40.1/24 (Station-4)"
echo "  VLAN50:       ens8 → 172.16.50.1/24 (Station-5)"
echo "  VLAN60:       ens9 → 172.16.60.1/24 (Station-6)"
echo ""
echo "Useful commands:"
echo "  Check bridges: ovs-vsctl show"
echo "  Check routes:  ip route show"
echo "  Reset:         /home/student/ot_switch_init.sh reset"
echo "  Restart svc:   systemctl restart ot-switch.service"
echo "====================================================================="
EOF

chmod +x /home/student/setup_ot_switch.sh
sudo /home/student/setup_ot_switch.sh
