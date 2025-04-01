#!/bin/bash

# 🖥️ Nodes voor verdeling (alleen prox00 en prox02)
NODES=("prox00" "prox02")

# 📥 Info opvragen
read -p "Hoeveel VM's wil je aanmaken? " COUNT
read -p "Start VMID (bijv. 200): " VMID_START
read -p "Naam prefix (bijv. TestServer): " NAME_PREFIX
read -p "Start IP (bijv. 10.24.7.100): " START_IP
read -p "Gebruikersnaam voor de VM's: " USERNAME

# 🌍 Netwerk + opslag instellingen
STORAGE="ceph-vm"
CLOUDINIT_DISK="ceph-vm:cloudinit"
BRIDGE="vmbr0"
GATEWAY="10.24.7.1"
DNS="8.8.8.8"
SUBNET_MASK="24"
IMAGE="ubuntu-22.04-server-cloudimg-amd64.img"
SSHKEY="$HOME/.ssh/id_rsa.pub"
RAM=2048
CORES=1
DISKSIZE=15

# ✅ Checks
if [[ ! -f $SSHKEY ]]; then
  echo "❌ SSH key niet gevonden op $SSHKEY"
  exit 1
fi

if [[ ! -f $IMAGE ]]; then
  echo "❌ Cloud image '$IMAGE' niet gevonden in $(pwd)"
  echo "💡 Download via:"
  echo "wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  exit 1
fi

# 🔁 Loop over aantal VM's
IP_SUFFIX=$(echo $START_IP | awk -F. '{print $4}')
BASE_IP=$(echo $START_IP | awk -F. '{print $1"."$2"."$3"."}')

for ((i=0; i<COUNT; i++)); do
  VMID=$((VMID_START + i))
  IP="${BASE_IP}$((IP_SUFFIX + i))"
  VMNAME="${NAME_PREFIX}-$((i+1))"
  NODE=${NODES[$((i % 2))]}  # Om en om prox00 / prox02

  echo "🚧 VM $VMID ($VMNAME) wordt aangemaakt op $NODE met IP $IP..."

  # 1. Create lege VM
  qm create $VMID --name $VMNAME --memory $RAM --cores $CORES --net0 virtio,bridge=$BRIDGE --node $NODE

  # 2. Import cloud image als disk
  qm importdisk $VMID $IMAGE $STORAGE --node $NODE

  # 3. Koppel disk
  qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${VMID}-disk-0 --node $NODE

  # 3.1 Resize disk
  qm resize $VMID scsi0 ${DISKSIZE}G --node $NODE

  # 4. Cloud-init drive
  qm set $VMID --ide2 $CLOUDINIT_DISK --node $NODE

  # 5. Boot config + console
  qm set $VMID --boot order=scsi0 --serial0 socket --vga serial0 --node $NODE

  # 6. Cloud-init config
  qm set $VMID --ciuser $USERNAME --cipassword changeme123 --sshkey $SSHKEY --ipconfig0 ip=${IP}/${SUBNET_MASK},gw=${GATEWAY} --nameserver $DNS --node $NODE

  # 7. Starten
  qm start $VMID --node $NODE

  echo "✅ $VMNAME is succesvol aangemaakt en gestart op $NODE!"
done

echo "🎉 Klaar! $COUNT VM(s) zijn succesvol verdeeld over prox00 en prox02."