#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <domain> <id>"
    exit 1
fi

DOMAIN="$1"
echo "Using domain: $DOMAIN"
sed -i "s/server_name _;/server_name $DOMAIN;/g" ./conf/nginx_conf/default

id="$2"
echo "Using id: $id"
sed -i "s/\"id\": \"\"/\"id\": \"$id\"/g" ./conf/v2ray_conf/config.json

# 校准系统时间
echo "Synchronizing system time..."
timedatectl set-timezone Asia/Shanghai

# 安装相应软件包
echo "Installing packages..."
apt update
apt upgrade -y
apt install curl openssl cron socat nginx -y

# 安装 v2ray
echo "Installing v2ray..."
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
bash install-release.sh

# 配置证书
echo "Generating and Installing certificate for $DOMAIN ..."
systemctl stop nginx
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m test@example.com
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --keylength ec-256 --force
mkdir -p /etc/v2ray
~/.acme.sh/acme.sh --installcert -d $DOMAIN --ecc --fullchain-file /etc/v2ray/v2ray.crt --key-file /etc/v2ray/v2ray.key

# 替换相应文件
echo "Replacing files..."
rm -rf /usr/local/etc/v2ray/config.json
rm -rf /etc/nginx/sites-available/default
cp ./conf/v2ray_conf/config.json /usr/local/etc/v2ray/config.json
cp ./conf/nginx_conf/default /etc/nginx/sites-available/default
cp -R ./conf/web /var/www/html/

# 重启服务
echo "Restarting services..."
systemctl start nginx v2ray
systemctl enable v2ray
/lib/systemd/systemd-sysv-install enable nginx

echo "Done!"