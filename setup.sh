#!/bin/sh

# 配置 Alpine 源
# 使用 edge 源以获取最新的 sing-box
# 保留 main 和 community 源以确保 sing-box 的依赖可被满足
cat > /etc/apk/repositories <<EOF
@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
EOF

# 安装 sing-box
apk update
apk add sing-box@testing
rm -rf /var/cache/apk/*

# 安装 cloudflared
# 从 Github 下载到 /usr/bin 目录下
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/bin/cloudflared
# 赋予执行权限
chmod +x /usr/bin/cloudflared

# 执行启动脚本
exec /app/launch.sh