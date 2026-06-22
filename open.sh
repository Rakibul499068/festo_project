#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=================================================="
echo " Starting Open vSwitch Installation for GNS3 Ubuntu"
echo "=================================================="

# 1. Update package lists
echo "[*] Updating package repositories..."
sudo apt-get update -y

# 2. Install Open vSwitch and useful networking utilities
echo "[*] Installing Open vSwitch and network tools..."
sudo apt-get install -y openvswitch-switch openvswitch-common tcpdump tshark iproute2 net-tools curl

# 3. Enable and start the Open vSwitch service
echo "[*] Enabling and starting Open vSwitch service..."
sudo systemctl enable openvswitch-switch
sudo systemctl start openvswitch-switch

# 4. Enable IPv4 Forwarding (crucial for GNS3 routing/switching nodes)
echo "[*] Enabling IPv4 forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
# Make it persistent across reboots
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi

echo "=================================================="
echo " Installation Complete!"
echo " Verification:"
echo "=================================================="
sudo ovs-vsctl --version
sudo systemctl status openvswitch-switch --no-pager

echo ""
echo "You can now create bridges using: sudo ovs-vsctl add-br br0"
