#!/bin/bash

# 1. Write the background startup routine targeting ens interfaces
cat << 'INNER' > /usr/local/bin/ovs-switch2-startup.sh
#!/bin/bash
sleep 2

echo "=== Initializing Permanent Switch 2 Bridge ==="
ovs-vsctl del-br br-st2 2>/dev/null
ovs-vsctl add-br br-st2

# Force all ens physical interfaces to wake up
for i in 3 4 5 6; do
    ip link set dev ens$i up 2>/dev/null
done

# Attach active ens links to the flat switch bridge
for port in ens3 ens4 ens5 ens6; do
    if ip link show $port &>/dev/null; then
        ovs-vsctl add-port br-st2 $port 2>/dev/null
        echo "Attached physical port $port to br-st2"
    fi
done

ip link set dev br-st2 up
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

# 4. Enable and start the service right now
systemctl daemon-reload
systemctl enable ovs-switch2-persistent.service
systemctl restart ovs-switch2-persistent.service

echo "=== SUCCESS: Switch 2 configuration is now persistent using ens interfaces! ==="
