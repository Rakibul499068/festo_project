cat << 'EOF' > setup-switch.sh
#!/bin/bash

echo "=== Step 1: Initializing Open vSwitch Bridge ==="
# Delete old bridge if it exists to prevent duplicate errors, then create fresh
ovs-vsctl del-br br-it 2>/dev/null
ovs-vsctl add-br br-it

echo "=== Step 2: Provisioning Switch Fabric Ports ==="
# Loop through all designated interfaces, bring them up, and plug them into the bridge
for i in {4..11}; do
    ip link set ens${i} up
    ovs-vsctl add-port br-it ens${i}
    echo "Port ens${i} successfully mapped to br-it."
done

# Bring up the virtual bridge itself
ip link set br-it up

echo "=== Step 3: Creating Persistence Systemd Service ==="
# Create a systemd service file to automatically bring up interfaces on boot
cat << 'SYSTEMD' > /etc/systemd/system/it-switch-ports.service
[Unit]
Description=Ensure all IT Switch interfaces are UP on boot
After=openvswitch-switch.service
Requires=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for i in {4..11}; do ip link set ens${i} up; done; ip link set br-it up'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SYSTEMD

echo "=== Step 4: Activating Persistence Service ==="
# Reload systemd, enable the service to run on boot, and start it
systemctl daemon-reload
systemctl enable it-switch-ports.service
systemctl start it-switch-ports.service

echo "=== Verification ==="
ovs-vsctl show
echo "========================================================="
echo " SUCCESS: IT-Switch is ready and configuration is persistent."
echo "========================================================="
EOF
