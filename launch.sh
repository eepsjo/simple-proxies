#!/bin/sh

echo "--------------------------------------------------"
echo "simple-hy2 啟動中..."
echo "--------------------------------------------------"

# Hysteria
echo "【 hysteria 】"
EFFECTIVE_PASSWORD=""
if [ -n "$password" ]; then
    EFFECTIVE_PASSWORD="$password"
else
    EFFECTIVE_PASSWORD=$(openssl rand -base64 12)
fi
cat > 0.yaml <<EOF
listen: :6969
auth:
  type: password
  password: ${EFFECTIVE_PASSWORD}
tls:
  alpn: h3
  cert: /app/cert.pem
  key: /app/key.pem
EOF
echo "hysteria 配置已部署，監聽端口: 6969"
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /app/key.pem -out /app/cert.pem -subj "/CN=localhost" -days 3650

# output
location="${location:-default}"
echo "--------------------------------------------------"
echo "simple-hy2 啟動成功"
echo "--------------------------------------------------"
echo "【 節點鏈接 】"
echo "複製下面的模板，然後將其中 'example.com:6969' 部分替換為公共地址和埠"
echo "模板:"
echo "    hy2://${EFFECTIVE_PASSWORD}@example.com:6969?insecure=1&alpn=h3#${location}_simple-hy2"
echo "--------------------------------------------------"
echo "【 日誌 】"

# exec
sleep 2
exec /usr/bin/hysteria server -c /app/0.yaml
