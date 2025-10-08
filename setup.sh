#!/bin/sh

cat > /etc/apk/repositories <<EOF
@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
EOF
apk update
apk add sing-box@testing tor
rm -rf /var/cache/apk/*

wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/bin/cloudflared
chmod +x /usr/bin/cloudflared

exec /app/launch.sh
