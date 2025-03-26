#!/bin/bash

# Instellingen voor de VM
VMID=101
VMNAME="mijn-vm"
ISO_PATH="local:iso/debian-12.iso"
STORAGE="local-lvm"
DISK_SIZE="10G"
RAM="2048"     # in MB
CORES="2"
NET_BRIDGE="vmbr0"

# VM aanmaken
qm create $VMID --name $VMNAME --memory $RAM --cores $CORES --net0 virtio,bridge=$NET_BRIDGE

# ISO koppelen en opstarten van cdrom
qm set $VMID --ide2 $ISO_PATH,media=cdrom
qm set $VMID --boot order=ide2

# Disk aanmaken en koppelen
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$(echo $DISK_SIZE | sed 's/G//') # converteert 10G naar 10

# Start de VM (optioneel)
qm start $VMID

echo "VM $VMID ($VMNAME) is aangemaakt en gestart."
