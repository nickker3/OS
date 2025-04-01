#!/bin/bash

# 📥 Invoer opvragen
read -p "Hoeveel WordPress-containers wil je aanmaken? " COUNT
read -p "Start VMID (bijv. 300): " VMID_START
read -p "Naam prefix (bijv. WP): " NAME_PREFIX
read -p "Start IP (bijv. 10.24.7.100): " START_IP

# ⚙️ Basisinstellingen
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
STORAGE="local-lvm"
BRIDGE="vmbr0"
GATEWAY="10.24.7.1"
DNS="8.8.8.8"
SUBNET_MASK="24"
MYSQL_PASSWORD="wordpressdb"
CONTAINER_PASSWORD="wordpress123"

# 🧠 Functie om IP-adres op te hogen
function increment_ip() {
  local IFS=.
  read -r i1 i2 i3 i4 <<< "$1"
  echo "$i1.$i2.$i3.$((i4 + 1))"
}

CURRENT_IP="$START_IP"

# 🔁 Loop door alle containers
for ((i=0; i<COUNT; i++)); do
  VMID=$((VMID_START + i))
  HOSTNAME="${NAME_PREFIX}-${VMID}"

  echo "➡️  [$VMID] Container $HOSTNAME wordt aangemaakt op IP $CURRENT_IP..."

  # ✅ LXC container aanmaken
  pct create $VMID $TEMPLATE \
    --hostname $HOSTNAME \
    --storage $STORAGE \
    --net0 name=eth0,bridge=$BRIDGE,ip=$CURRENT_IP/$SUBNET_MASK,gw=$GATEWAY \
    --nameserver $DNS \
    --memory 1024 \
    --cores 1 \
    --password $CONTAINER_PASSWORD \
    --unprivileged 1

  pct start $VMID
  sleep 5

  echo "⚙️  [$VMID] WordPress en dependencies worden geïnstalleerd..."

  pct exec $VMID -- bash -c "
    apt update &&
    apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc wget unzip &&
    service mysql start &&
    mysql -e \"
      CREATE DATABASE wordpress;
      CREATE USER 'wpuser'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
      GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
      FLUSH PRIVILEGES;\"

    cd /var/www/html &&
    rm index.html &&
    wget https://wordpress.org/latest.zip &&
    unzip latest.zip &&
    mv wordpress/* . &&
    rmdir wordpress &&
    rm latest.zip &&
    chown -R www-data:www-data /var/www/html

    cat > /var/www/html/wp-config.php <<EOF
<?php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wpuser' );
define( 'DB_PASSWORD', '$MYSQL_PASSWORD' );
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

    systemctl restart apache2
  "

  echo "✅ [$VMID] WordPress-container actief: http://$CURRENT_IP"

  CURRENT_IP=$(increment_ip $CURRENT_IP)
done

echo "🎉 Alle WordPress-containers zijn aangemaakt!"
