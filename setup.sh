#!/bin/sh

apk update
apk add openssl
rm -rf /var/cache/apk/*

wget https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64 -O /usr/bin/hysteria
chmod +x /usr/bin/hysteria

exec /app/launch.sh