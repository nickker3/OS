#!/bin/bash

# === Instellingen ===
ISO_PATH="local:iso/ubuntu-22.04.5-live-server-amd64.iso"  # Zorg dat dit bestand al is geüpload
STORAGE="ceph-vm"
NET_BRIDGE="vmbr0"

BASE_IP="10.24.7."
START_IP_SUFFIX=100
GATEWAY="10.24.7.1"
DNS="8.8.8.8"
SUBNET="255.255.255.0"

RAM=2048
CORES=1
DISK_SIZE=15
VMID_START=200
NAME_PREFIX="TestServer"

# === Input ===
read -p "Hoeveel servers wil je aanmaken? " COUNT

# === Loop over aantal VMs ===
for ((i=0; i<COUNT; i++)); do
    VMID=$((VMID_START + i))
    IP_SUFFIX=$((START_IP_SUFFIX + i))
    IP="${BASE_IP}${IP_SUFFIX}"
    VM_NAME="${NAME_PREFIX}-${i+1}"

    echo "🛠️  Maken van VM $VMID ($VM_NAME) met IP $IP..."

    qm create $VMID \
        --name $VM_NAME \
        --memory $RAM \
        --cores $CORES \
        --net0 virtio,bridge=$NET_BRIDGE \
        --ide2 $ISO_PATH,media=cdrom \
        --boot order=ide2 \
        --scsihw virtio-scsi-pci \
        --scsi0 ${STORAGE}:${DISK_SIZE} \
        --Default  \
        --vga serial0

    # Start de VM automatisch
    qm start $VMID

    echo "✅ VM $VMID ($VM_NAME) is aangemaakt en gestart."
done

echo "🎉 Klaar! $COUNT VM(s) zijn succesvol aangemaakt en gestart."
