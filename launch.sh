#!/bin/sh

# env
port="${port:-20000}"
pwd="${pwd}"
tag="${tag:-default}"

# Hysteria2
echo "--------------------------------------------------"
echo "simple-hy2 啟動中..."
echo "--------------------------------------------------"
echo "【 Hysteria2 】"
if [ -z "$pwd" ]; then
    pwd=$(openssl rand -base64 12)
fi
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /app/key.pem -out /app/cert.pem -subj "/CN=bing.com" -days 3650
cat > 0.yaml <<EOF
listen: :${port}
tls:
  alpn: h3
  cert: /app/cert.pem
  key: /app/key.pem
auth:
  type: password
  password: ${pwd}
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
ignoreClientBandwidth: false
EOF
echo "Hysteria2 配置已部署"
sleep 3
nohup hysteria server -c 0.yaml > /dev/null 2>&1 &

# output
echo "--------------------------------------------------"
echo "simple-hy2 啟動成功"
echo "--------------------------------------------------"
echo "【 節點鏈接 】"
echo "⭐ 複製下方模板，將其中 'example.com:port' 替換為公共地址和埠"
echo "    hy2://${pwd}@example.com:port?insecure=1&alpn=h3#${tag}_simple-hy2"
echo "--------------------------------------------------"

# keep
tail -f /dev/null