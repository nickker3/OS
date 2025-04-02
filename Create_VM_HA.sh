#!/bin/bash

# 🖥️ Beschikbare nodes
NODES=("prox00" "prox02")

# 📥 Info opvragen
read -p "Hoeveel VM's wil je aanmaken? " COUNT
read -p "Start VMID (bijv. 200): " VMID_START
read -p "Naam prefix (bijv. TestServer): " NAME_PREFIX
read -p "Start IP (bijv. 10.24.7.100): " START_IP

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
USERNAME="vmuser"
PASSWORD="changeme123"
HA_GROUP="cluster"

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

  USERDATA_FILE="/tmp/user-${VMID}.yml"
  cat <<EOF > "$USERDATA_FILE"
#cloud-config
users:
  - name: $USERNAME
    gecos: Automatisch gegenereerde gebruiker
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    plain_text_passwd: $PASSWORD
    lock_passwd: false
    ssh_authorized_keys:
      - $(cat "$SSHKEY_PATH")

ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false

runcmd:
  - apt update
  - apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc wget unzip
  - systemctl enable apache2
  - systemctl start apache2
  - systemctl start mysql
  - mysql -e "CREATE DATABASE wordpress; CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'wordpressdb'; GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost'; FLUSH PRIVILEGES;"
  - cd /var/www/html
  - rm index.html || true
  - wget https://wordpress.org/latest.zip
  - unzip latest.zip
  - mv wordpress/* .
  - rmdir wordpress
  - rm latest.zip
  - chown -R www-data:www-data /var/www/html
  - |
    cat > /var/www/html/wp-config.php <<EOF
    <?php
    define( 'DB_NAME', 'wordpress' );
    define( 'DB_USER', 'wpuser' );
    define( 'DB_PASSWORD', 'wordpressdb' );
    define( 'DB_HOST', 'localhost' );
    define( 'DB_CHARSET', 'utf8' );
    define( 'DB_COLLATE', '' );
    \$table_prefix = 'wp_';
    define( 'WP_DEBUG', false );
    if ( ! defined( 'ABSPATH' ) ) {
      define( 'ABSPATH', __DIR__ . '/' );
    }
    require_once ABSPATH . 'wp-settings.php';
    EOF
  - systemctl restart apache2

  scp "$USERDATA_FILE" "$NODE:/var/lib/vz/snippets/user-${VMID}.yml"
  rm "$USERDATA_FILE"

  ssh "$NODE" bash -c "'
    qm create $VMID --name $VMNAME --memory $RAM --cores $CORES --net0 virtio,bridge=$BRIDGE &&
    qm importdisk $VMID $REMOTE_IMAGE_PATH $STORAGE &&
    qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${VMID}-disk-0 &&
    qm resize $VMID scsi0 ${DISKSIZE}G &&
    qm set $VMID --ide2 $CLOUDINIT_DISK &&
    qm set $VMID --boot order=scsi0 --vga std &&
    qm set $VMID --ipconfig0 ip=${IP}/${SUBNET_MASK},gw=${GATEWAY} --nameserver $DNS &&
    qm set $VMID --cicustom user=local:snippets/user-${VMID}.yml &&
    qm start $VMID &&
    ha-manager add vm:$VMID --group $HA_GROUP || echo '⚠️ HA toevoegen mislukt voor VM $VMID'
  '"

  if ssh "$NODE" "qm status $VMID | grep -q running"; then
    STATUS="✅ gestart"
  else
    STATUS="❌ niet gestart"
  fi

  echo "$VMNAME | VMID: $VMID | Node: $NODE | IP: $IP | OS: Ubuntu 22.04 | User: $USERNAME | Wachtwoord: $PASSWORD | Status: $STATUS" | tee -a "$LOG_FILE"
done

echo "-------------------------------------------" >> "$LOG_FILE"
echo "Einde log op $(date)" >> "$LOG_FILE"
echo "✅ Logbestand opgeslagen: $LOG_FILE"