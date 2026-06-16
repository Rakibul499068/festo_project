#!/bin/bash

# 1. Write the dynamic background startup routine
cat << 'INNER' > /usr/local/bin/ovs-switch2-startup.sh
#!/bin/bash
sleep 2

echo "=== Cleaning and Rebuilding Switch 2 Bridge ==="
ovs-vsctl del-br br-st2 2>/dev/null
ovs-vsctl add-br br-st2

# Automatically discover ANY network interface that starts with 'ens'
interfaces=$(ip -br link show | awk '{print $1}' | grep '^ens')

for port in $interfaces; do
    # Wake up the port
    ip link set dev $port up 2>/dev/null
    
    # Add it to the bridge
    ovs-vsctl add-port br-st2 $port 2>/dev/null
    echo "Successfully attached active physical port: $port"
done

ip link set dev br-st2 up
echo "=== FINISHED: Switch 2 is permanently operational ==="
INNER

# 2. Make it executable
chmod +x /usr/local/bin/ovs-switch2-startup.sh

# 3. Create the systemd configuration file
cat << 'INNER' > /etc/systemd/system/ovs-switch2-persistent.service
[Unit]
Description=Persistent Switch 2 Layer 2 Configuration
After=openvswitch-switch.service network-online.target
Wants=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ovs-switch2-startup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
INNER

# 4. Enable and start the service
systemctl daemon-reload
systemctl enable ovs-switch2-persistent.service
systemctl restart ovs-switch2-persistent.service

echo "=== SUCCESS: Switch 2 configuration is now dynamically persistent! ==="
