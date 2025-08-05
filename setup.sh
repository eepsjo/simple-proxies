#!/bin/sh

cat > /etc/apk/repositories <<EOF
@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
EOF
apk update
apk add sing-box@testing
rm -rf /var/cache/apk/*

exec /app/launch.sh
