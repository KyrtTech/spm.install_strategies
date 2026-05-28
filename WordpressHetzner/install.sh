#!/bin/bash
set -euo pipefail

PUBLIC_HOST="${WORDPRESS_HETZNER_DOMAIN_OR_IP:-${IP:-}}"
WORDPRESS_SOURCE="${DOWNLOAD_URL:-https://wordpress.org/latest.zip}"

if [ -z "${PUBLIC_HOST}" ]; then
  PUBLIC_HOST=$(echo "${SSH_CONNECTION_STRING}" | awk -F@ '{print $NF}')
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "${SSH_CONNECTION_STRING}" \
  -i "${SSH_KEY}" \
  "WORDPRESS_SOURCE='${WORDPRESS_SOURCE}'" \
  "PUBLIC_HOST='${PUBLIC_HOST}'" \
  'bash -s' <<'EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y apache2 mariadb-server unzip curl pwgen \
  php8.3 php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-gd \
  php8.3-mbstring php8.3-mysql php8.3-xml php8.3-zip libapache2-mod-php8.3

systemctl enable apache2 mariadb
systemctl start apache2 mariadb

DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASSWORD=$(pwgen -s 24 1)

mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

rm -rf /tmp/wordpress.zip /tmp/wordpress /var/www/wordpress
if ! curl -fsSL -o /tmp/wordpress.zip "${WORDPRESS_SOURCE}"; then
  curl -fsSL -o /tmp/wordpress.zip "https://wordpress.org/latest.zip"
fi

unzip -q /tmp/wordpress.zip -d /tmp
mv /tmp/wordpress /var/www/wordpress
chown -R www-data:www-data /var/www/wordpress
find /var/www/wordpress -type d -exec chmod 755 {} \;
find /var/www/wordpress -type f -exec chmod 644 {} \;

cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
sed -i "s/database_name_here/${DB_NAME}/" /var/www/wordpress/wp-config.php
sed -i "s/username_here/${DB_USER}/" /var/www/wordpress/wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" /var/www/wordpress/wp-config.php
sed -i "s/localhost/localhost/" /var/www/wordpress/wp-config.php

SALT=$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/)
awk -v salt="${SALT}" '
  /AUTH_KEY/ && !done { print salt; done=1; next }
  /SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT/ { next }
  { print }
' /var/www/wordpress/wp-config.php > /var/www/wordpress/wp-config.tmp
mv /var/www/wordpress/wp-config.tmp /var/www/wordpress/wp-config.php
chown www-data:www-data /var/www/wordpress/wp-config.php

cat > /etc/apache2/sites-available/wordpress.conf <<APACHE
<VirtualHost *:80>
    ServerName ${PUBLIC_HOST}
    DocumentRoot /var/www/wordpress

    <Directory /var/www/wordpress>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
APACHE

a2enmod rewrite
a2dissite 000-default.conf
a2ensite wordpress.conf
systemctl reload apache2
EOF

if [ -z "${SPM_OUTPUT_PATH:-}" ]; then
  echo "No output for SPM"
else
  cat > "${SPM_OUTPUT_PATH}" <<EOF
{"output_params": {
  "url": "http://${PUBLIC_HOST}"
}}
EOF
fi
