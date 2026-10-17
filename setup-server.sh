#!/usr/bin/env bash
# Medicaps workshop — runs ON the EC2 instance (CentOS Stream 9) as root/sudo.
# Encodes runbook steps 01-04 and 07: Nginx, Forno-web, Node/PM2/CloudWall,
# the single Nginx config, and Zabbix server+agent.
# Usage: edit the variables below, then: sudo bash setup-server.sh
set -euo pipefail

# ============== EDIT ME ==============
FORNO_REPO_URL="https://github.com/shivamverma789/Forno-web.git"
CLOUDWALL_REPO_URL="https://github.com/shivamverma789/CloudWall.git"
TIMEZONE="Asia/Kolkata"
ZABBIX_DB_PASSWORD="${ZABBIX_DB_PASSWORD:-}"   # leave blank to auto-generate
# ======================================

log(){ echo -e "\n>>> $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0"; exit 1
fi

STATE_DIR="/opt/medicaps-setup"
mkdir -p "$STATE_DIR"

# ---------- 01: base packages ----------
log "Base packages"
dnf update -y
dnf install -y git firewalld
systemctl enable --now firewalld

# ---------- 02: Nginx + Forno-web ----------
log "Installing Nginx"
dnf install -y nginx
systemctl enable --now nginx
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

log "Deploying Forno-web"
git config --global --add safe.directory /var/www/forno-web
if [[ -d /var/www/forno-web/.git ]]; then
  git -C /var/www/forno-web pull
else
  rm -rf /var/www/forno-web
  git clone "$FORNO_REPO_URL" /var/www/forno-web
fi
chown -R nginx:nginx /var/www/forno-web
chcon -Rt httpd_sys_content_t /var/www/forno-web

# ---------- 03: Node.js + PM2 + CloudWall ----------
# better-sqlite3@13.x's native addon genuinely needs Node >=22 at runtime —
# on Node 20 it loads fine but segfaults the moment a Database() is opened.
# Checking the actual major version (not just "is node installed") matters
# because a re-run must still upgrade an instance stuck on an older stream.
log "Installing Node.js 22"
CURRENT_NODE_MAJOR="$(node -v 2>/dev/null | sed 's/^v//;s/\..*//')"
if [[ "${CURRENT_NODE_MAJOR:-0}" -lt 22 ]]; then
  dnf module reset nodejs -y || true
  dnf module enable nodejs:22 -y
  dnf install -y nodejs
fi

log "Installing native build tools (better-sqlite3 compiles from source via node-gyp)"
dnf install -y gcc gcc-c++ make python3

log "Deploying CloudWall"
if [[ -d /opt/cloudwall/.git ]]; then
  git -C /opt/cloudwall pull
else
  rm -rf /opt/cloudwall
  git clone "$CLOUDWALL_REPO_URL" /opt/cloudwall
fi
cd /opt/cloudwall

# Force a clean native rebuild if the Node major version changed since the
# last run — a stale node_modules here is exactly what caused the segfault.
NODE_MAJOR_NOW="$(node -v | sed 's/^v//;s/\..*//')"
if [[ ! -f .node_major || "$(cat .node_major)" != "$NODE_MAJOR_NOW" ]]; then
  echo "Node version changed (or first run) — forcing a clean native rebuild"
  rm -rf node_modules package-lock.json
fi
npm install
echo "$NODE_MAJOR_NOW" > .node_major

# Installed locally (not -g) and called by direct path below — sidesteps
# every global-prefix/PATH inconsistency across dnf's node module streams.
npm install pm2 --no-save >/dev/null
PM2="/opt/cloudwall/node_modules/.bin/pm2"

if [[ ! -f .env ]]; then
  SESSION_SECRET="$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"
  cat > .env <<EOF
PORT=3000
SESSION_SECRET=${SESSION_SECRET}
EOF
  echo "Generated new .env with a fresh SESSION_SECRET."
else
  echo ".env already exists — leaving it untouched."
fi

log "Starting CloudWall with PM2"
"$PM2" describe cloudwall >/dev/null 2>&1 \
  && "$PM2" restart cloudwall \
  || "$PM2" start /opt/cloudwall/app.js --name cloudwall
"$PM2" save
"$PM2" startup systemd -u root --hp /root | grep '^sudo' | bash || true

sleep 2
curl -sf http://127.0.0.1:3000 >/dev/null && echo "CloudWall responding on :3000" \
  || echo "WARNING: CloudWall did not respond on :3000 — check '$PM2 logs cloudwall'"

# ---------- 04: single Nginx config ----------
log "Writing a clean /etc/nginx/nginx.conf (removes the stock embedded server block)"
if [[ ! -f "$STATE_DIR/nginx.conf.orig" ]]; then
  cp /etc/nginx/nginx.conf "$STATE_DIR/nginx.conf.orig"
fi
cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout    65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # All routing for this project lives in /etc/nginx/conf.d/medicaps.conf
    include /etc/nginx/conf.d/*.conf;
}
EOF

log "Writing /etc/nginx/conf.d/medicaps.conf (frontend + backend, one file)"
cat > /etc/nginx/conf.d/medicaps.conf <<'EOF'
# ================================================
# FRONTEND — Forno-web (static files, served directly)
# ================================================
server {
    listen 80;
    server_name _;

    root /var/www/forno-web;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

# ================================================
# BACKEND — CloudWall (Node/Express via PM2 on :3000)
# ================================================
server {
    listen 8080;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF

setsebool -P httpd_can_network_connect on
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
nginx -t
systemctl reload nginx

# ---------- 07: Zabbix server + agent ----------
log "Installing Zabbix"
if [[ -z "$ZABBIX_DB_PASSWORD" ]]; then
  ZABBIX_DB_PASSWORD="$(openssl rand -base64 18)"
fi

if [[ ! -f /etc/yum.repos.d/zabbix.repo ]]; then
  rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/9/x86_64/zabbix-release-6.0-4.el9.noarch.rpm
  dnf clean all
fi

dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-nginx-conf \
    zabbix-sql-scripts zabbix-agent mariadb-server

systemctl enable --now mariadb

# Non-interactive equivalent of mysql_secure_installation
mysql -uroot <<SQL || true
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

if ! mysql -uroot -e "USE zabbix" >/dev/null 2>&1; then
  mysql -uroot <<SQL
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${ZABBIX_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
SQL
  zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | \
    mysql --default-character-set=utf8mb4 -uzabbix -p"${ZABBIX_DB_PASSWORD}" zabbix
  echo "${ZABBIX_DB_PASSWORD}" > "$STATE_DIR/zabbix_db_password.txt"
  chmod 600 "$STATE_DIR/zabbix_db_password.txt"
  echo "Zabbix DB created. Password saved at $STATE_DIR/zabbix_db_password.txt"
else
  echo "Zabbix DB already exists — skipping schema import."
  if [[ -f "$STATE_DIR/zabbix_db_password.txt" ]]; then
    ZABBIX_DB_PASSWORD="$(cat "$STATE_DIR/zabbix_db_password.txt")"
  fi
fi

sed -i "s|^# DBPassword=.*|DBPassword=${ZABBIX_DB_PASSWORD}|; s|^DBPassword=.*|DBPassword=${ZABBIX_DB_PASSWORD}|" /etc/zabbix/zabbix_server.conf
grep -q "^DBPassword=" /etc/zabbix/zabbix_server.conf || echo "DBPassword=${ZABBIX_DB_PASSWORD}" >> /etc/zabbix/zabbix_server.conf

sed -i 's/^\s*#\?\s*listen\s\+8080;/        listen       8081;/' /etc/nginx/conf.d/zabbix.conf
sed -i 's/^\s*#\?\s*server_name\s\+example.com;/        server_name  _;/' /etc/nginx/conf.d/zabbix.conf

if ! grep -q "date.timezone = ${TIMEZONE}" /etc/php-fpm.d/zabbix.conf 2>/dev/null; then
  sed -i "s#^php_value\[date.timezone\].*#php_value[date.timezone] = ${TIMEZONE}#" /etc/php-fpm.d/zabbix.conf
fi

setsebool -P httpd_can_connect_zabbix on

# 8080 is in SELinux's default httpd port list, 8081 is not — without this,
# Nginx parses the config fine but silently fails to bind :8081.
command -v semanage >/dev/null 2>&1 || dnf install -y policycoreutils-python-utils
semanage port -a -t http_port_t -p tcp 8081 2>/dev/null || semanage port -m -t http_port_t -p tcp 8081 2>/dev/null || true

firewall-cmd --permanent --add-port=8081/tcp
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --reload

systemctl enable --now zabbix-server zabbix-agent php-fpm
nginx -t
systemctl reload nginx

PUBLIC_IP="$(curl -s ifconfig.me || hostname -I | awk '{print $1}')"

cat <<SUMMARY

========================================================
 Setup complete
========================================================
 Forno-web   : http://${PUBLIC_IP}
 CloudWall   : http://${PUBLIC_IP}:8080
 Zabbix      : http://${PUBLIC_IP}:8081   (run the setup wizard manually)
   DB name     : zabbix
   DB user     : zabbix
   DB password : see ${STATE_DIR}/zabbix_db_password.txt
   Default login: Admin / zabbix  (change immediately)

 Next manual steps:
   1. Finish the Zabbix web setup wizard at the URL above.
   2. In Zabbix: Data collection > Hosts > Create host
      Name: Workshop-EC2, Agent interface 127.0.0.1:10050,
      template "Linux by Zabbix agent".
   3. Run workshop-scripts/setup-aws.sh LOCALLY (not on this
      instance) to provision the S3 demo bucket + IAM users.
========================================================
SUMMARY
