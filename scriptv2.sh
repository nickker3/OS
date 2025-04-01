#!/bin/bash

# 🖥️ Beschikbare nodes (alleen bestaande!)
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
REMOTE_IMAGE_PATH="/root/$IMAGE"
SSHKEY_PATH="$HOME/.ssh/id_rsa.pub"
RAM=2048
CORES=1
DISKSIZE=15

# ✅ Checks
if [[ ! -f "$SSHKEY_PATH" ]]; then
  echo "❌ SSH key niet gevonden op: $SSHKEY_PATH"
  exit 1
fi

if [[ ! -f $IMAGE ]]; then
  echo "❌ Cloud image '$IMAGE' niet gevonden in $(pwd)"
  echo "💡 Download via:"
  echo "wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  exit 1
fi

# 📁 Logbestand aanmaken
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/Log_$(date +'%Y-%m-%d_%H-%M-%S').log"

echo "📝 Logging naar: $LOG_FILE"
echo "-------------------------------------------" >> "$LOG_FILE"
echo "Start log op $(date)" >> "$LOG_FILE"
echo "-------------------------------------------" >> "$LOG_FILE"

# 🔎 Controleer SSH toegang tot nodes
REACHABLE_NODES=()
for NODE in "${NODES[@]}"; do
  if ssh -o ConnectTimeout=5 $NODE "echo OK" &>/dev/null; then
    echo "✅ Node bereikbaar via SSH: $NODE"
    REACHABLE_NODES+=("$NODE")
  else
    echo "❌ Kan geen verbinding maken met node: $NODE"
  fi
done

if [ ${#REACHABLE_NODES[@]} -eq 0 ]; then
  echo "❌ Geen enkele node is bereikbaar. Stoppen."
  exit 1
fi

# 📤 Kopieer image naar bereikbare nodes
for NODE in "${REACHABLE_NODES[@]}"; do
  echo "🔍 Controleren of $IMAGE aanwezig is op $NODE..."
  if ! ssh $NODE "[ -f $REMOTE_IMAGE_PATH ]"; then
    echo "📦 Image wordt gekopieerd naar $NODE..."
    scp "$IMAGE" "$NODE:$REMOTE_IMAGE_PATH"
  else
    echo "✅ Image is al aanwezig op $NODE"
  fi
done

# 🔁 Loop over aantal VM's
IP_SUFFIX=$(echo $START_IP | awk -F. '{print $4}')
BASE_IP=$(echo $START_IP | awk -F. '{print $1"."$2"."$3"."}')

for ((i=0; i<COUNT; i++)); do
  VMID=$((VMID_START + i))
  IP="${BASE_IP}$((IP_SUFFIX + i))"
  VMNAME="${NAME_PREFIX}-$((i+1))"
  NODE=${REACHABLE_NODES[$((i % ${#REACHABLE_NODES[@]}))]}

  if [[ ! "$VMNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Ongeldige VM-naam: $VMNAME. Alleen letters, cijfers, - of _ toegestaan."
    continue
  fi

  echo "🔍 Controleren of VMID $VMID al bestaat op $NODE..."
  if ssh $NODE "qm status $VMID" &>/dev/null; then
    echo "⚠️  VMID $VMID bestaat al op $NODE. Wordt overgeslagen."
    continue
  fi

  echo "🚧 VM $VMID ($VMNAME) wordt aangemaakt op $NODE met IP $IP..."

  TEMPKEY="/tmp/sshkey-${VMID}.pub"
  scp "$SSHKEY_PATH" "$NODE:$TEMPKEY"

  ssh "$NODE" bash -c "'
    qm create $VMID --name $VMNAME --memory $RAM --cores $CORES --net0 virtio,bridge=$BRIDGE &&
    qm importdisk $VMID $REMOTE_IMAGE_PATH $STORAGE &&
    qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${VMID}-disk-0 &&
    qm resize $VMID scsi0 ${DISKSIZE}G &&
    qm set $VMID --ide2 $CLOUDINIT_DISK &&
    qm set $VMID --boot order=scsi0 --vga std &&
    qm set $VMID --ciuser $USERNAME --cipassword changeme123 --sshkey $TEMPKEY --ipconfig0 ip=${IP}/${SUBNET_MASK},gw=${GATEWAY} --nameserver $DNS &&
    qm start $VMID &&
    rm -f $TEMPKEY
  '"

  if ssh "$NODE" "qm status $VMID | grep -q running"; then
    STATUS="✅ gestart"
  else
    STATUS="❌ niet gestart"
  fi

  echo "$VMNAME | VMID: $VMID | Node: $NODE | IP: $IP | OS: Ubuntu 22.04 | User: $USERNAME | Wachtwoord: changeme123 | Status: $STATUS" | tee -a "$LOG_FILE"
done

echo "-------------------------------------------" >> "$LOG_FILE"
echo "Einde log op $(date)" >> "$LOG_FILE"
echo "✅ Logbestand opgeslagen: $LOG_FILE"
