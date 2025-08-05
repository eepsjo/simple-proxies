#!/bin/sh

echo "--------------------------------------------------"
echo "simple-vless 啟動中..."
echo "--------------------------------------------------"

# sing-box
echo "【 sing-box 】"
EFFECTIVE_UUID=""
if [ -n "$uuid" ]; then
    EFFECTIVE_UUID="$uuid"
else
    EFFECTIVE_UUID=$(sing-box generate uuid)
fi
cat > 0.json <<EOF
{
  "log": { "disabled": false, "level": "warn", "timestamp": true },
  "inbounds": [
    { "type": "vless", "tag": "proxy", "listen": "::", "listen_port": 2777,
      "users": [ { "uuid": "${EFFECTIVE_UUID}", "flow": "" } ],
      "transport": { "type": "ws", "path": "/${EFFECTIVE_UUID}", "max_early_data": 2048, "early_data_header_name": "Sec-WebSocket-Protocol" }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
EOF
echo "sing-box 配置已部署"
nohup sing-box run -c 0.json > /dev/null 2>&1 &
echo "--------------------------------------------------"

# Cloudflare Tunnel
sleep 2
echo "【 Cloudflared 】"
TUNNEL_MODE=""
FINAL_DOMAIN=""
TUNNEL_CONNECTED=false
if [ -n "$token" ] && [ -n "$domain" ]; then
    TUNNEL_MODE="固定隧道"
    FINAL_DOMAIN="$domain"
    echo "檢測到 token 和 domain 已配置，使用固定隧道模式"
    nohup cloudflared tunnel --no-autoupdate run --token "${token}" > ./0.log 2>&1 &
    echo "等待隧道連接..."
    for attempt in $(seq 1 15); do
        sleep 2
        if grep -q -E "Registered tunnel connection|Connected to .*, an Argo Tunnel an edge" ./0.log; then
            TUNNEL_CONNECTED=true
            break
        fi
    done
else
    TUNNEL_MODE="臨時隧道"
    echo "檢測到 token 或/和 domain 未配置，使用臨時隧道模式"
    nohup cloudflared tunnel --url http://localhost:2777 --edge-ip-version auto --no-autoupdate --protocol http2 > ./0.log 2>&1 &
    echo "等待臨時隧道分配..."
    for attempt in $(seq 1 15); do
        sleep 2
        TEMP_TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare.com' ./0.log | head -n 1)
        if [ -n "$TEMP_TUNNEL_URL" ]; then
            FINAL_DOMAIN=$(echo "$TEMP_TUNNEL_URL" | awk -F'//' '{print $2}')
            TUNNEL_CONNECTED=true
            break
        fi
    done
fi
if [ "$TUNNEL_CONNECTED" = "true" ]; then
    echo "$TUNNEL_MODE連接成功！"
    location="${location:-default}"
    path_encoded="%2F${EFFECTIVE_UUID}%3Fed%3D2048"

# output
    echo "--------------------------------------------------"
    echo "simple-vless 啟動成功"
    echo "--------------------------------------------------"
    echo "【 節點鏈接 】"
    echo "⭐ 複製下方連接粘貼到客戶端使用"
    for node_info in \
        "www.visa.com.tw:443:vTW" \
        "www.visa.com.hk:2053:vHK" \
        "www.visa.com.br:8443:vBR" \
        "www.visaeurope.ch:443:vCH" \
        "usa.visa.com:2053:vUS" \
        "icook.hk:8443:iHK" \
        "icook.tw:443:iTW"
    do
        OLDIFS=$IFS; IFS=':'; set -- $node_info; SERVER_ADDRESS="$1"; PORT="$2"; NODE_SUFFIX="$3"; IFS=$OLDIFS
		echo "    vless://${EFFECTIVE_UUID}@${SERVER_ADDRESS}:${PORT}?encryption=none&security=tls&sni=${FINAL_DOMAIN}&host=${FINAL_DOMAIN}&fp=chrome&type=ws&path=${path_encoded}#${location}_simple-vless_${NODE_SUFFIX}"
    done
    echo "--------------------------------------------------"
    echo "【 日誌 】"
    tail -f ./0.log
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "$TUNNEL_MODE 連接失敗"
    echo "請檢查日誌並確認配置"
    if [ "$TUNNEL_MODE" = "固定隧道" ]; then
        echo "確保 token 和 domain 正確配置"
    fi
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    cat ./0.log
    exit 1
fi
