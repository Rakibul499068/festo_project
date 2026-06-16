cat << 'EOF' > setup_plc.sh
#!/bin/bash

echo "=== Cleaning Up Previous Configs & Services ==="
systemctl stop plc.service 2>/dev/null
systemctl disable plc.service 2>/dev/null
rm -f /etc/systemd/system/plc.service
rm -f /usr/local/bin/plc.sh
systemctl daemon-reload

# 1. Create the persistent PLC networking script
cat << 'INNER' > /usr/local/bin/plc.sh
#!/bin/bash
sleep 2

echo "=== Setting up Permanent PLC IP ==="

# Automatically discover the active network interface (ens or eth)
interface=$(ip -br link show | awk '{print $1}' | grep -E '^(ens|eth)' | head -n 1)

if [ -z "$interface" ]; then
    echo "Error: No ens or eth network interface found!"
    exit 1
fi

echo "Configuring interface: $interface"

# Wake up the port and clear dirty configurations
ip link set dev $interface up
ip addr flush dev $interface 2>/dev/null

# Assign the static PLC IP and Gateway
ip addr add 172.16.11.10/24 dev $interface
ip route add default via 172.16.11.1 dev $interface

echo "PLC Network configuration successfully applied!"
INNER

# 2. Make it executable
chmod +x /usr/local/bin/plc.sh

# 3. Create the simple systemd service file
cat << 'INNER' > /etc/systemd/system/plc.service
[Unit]
Description=Permanent PLC Network Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/plc.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

# 4. Enable and start it permanently
systemctl daemon-reload
systemctl enable plc.service
systemctl restart plc.service

echo "=== DONE: PLC network configuration is permanent via plc.service! ==="
EOF

chmod +x setup_plc.sh
sudo ./setup_plc.sh
