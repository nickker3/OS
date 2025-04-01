#!/bin/bash

# Informatie opvragen
read -p "VM ID: " VMID
read -p "VM naam: " VMNAME
read -p "RAM in MB: " MEMORY
read -p "Aantal CPU cores: " CORES
read -p "Disk grootte in GB: " DISKSIZE
read -p "IP adres (bijv. 10.24.16.50/24): " IPADDR
read -p "Gebruikersnaam voor de VM: " USERNAME

# Variabelen
IMAGE="jammy-server-cloudimg-amd64.img"
STORAGE="POOLDENNIS"
CLOUDINIT_DISK="local-lvm:cloudinit"
BRIDGE="vmbr0"
GATEWAY="10.24.16.1"
DNS="8.8.8.8"
SSHKEY="$HOME/.ssh/id_rsa.pub"

# Checks
if [[ ! -f $SSHKEY ]]; then
  echo "❌ SSH key niet gevonden op $SSHKEY"
  exit 1
fi

if [[ ! -f $IMAGE ]]; then
  echo "❌ Cloud image '$IMAGE' niet gevonden in $(pwd)"
  echo "💡 Download via: wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  exit 1
fi

if (( DISKSIZE < 5 )); then
  echo "❗ Opgelet: minimale disk grootte is 5GB"
  exit 1
fi

echo "🚧 VM $VMID ($VMNAME) wordt aangemaakt..."

# 1. Create lege VM
qm create $VMID --name $VMNAME --memory $MEMORY --cores $CORES --net0 virtio,bridge=$BRIDGE

# 2. Import cloud image als disk in Ceph
qm importdisk $VMID $IMAGE $STORAGE

# 3. Koppel disk aan scsi0
qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${VMID}-disk-0

# 3.1 Resize disk
qm resize $VMID scsi0 ${DISKSIZE}G

# 4. Cloud-init drive op local-lvm
qm set $VMID --ide2 $CLOUDINIT_DISK

# 5. Boot instellingen + console via serial
qm set $VMID --boot order=scsi0
qm set $VMID --serial0 socket --vga serial0

# 6. Cloud-init instellingen
qm set $VMID --ciuser $USERNAME
qm set $VMID --cipassword changeme123
qm set $VMID --sshkey $SSHKEY
qm set $VMID --ipconfig0 ip=${IPADDR},gw=${GATEWAY}
qm set $VMID --nameserver $DNS

# 7. Start VM
qm start $VMID

echo "✅ VM $VMID ($VMNAME) is succesvol aangemaakt en gestart!"
