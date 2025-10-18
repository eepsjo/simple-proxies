#!/bin/sh

# env
# sing-box 监听的本地端口。默认值 20000
port="${port:-20000}" 
# 自定义 UUID，不填则使用临时隧道模式
uuid="${uuid}"
# (固定隧道模式) Cloudflare Tunnel 的 Access Token
token="${token}"
# (固定隧道模式) Cloudflare 域名
domain="${domain}"
# 节点名称前的标签，方便区分节点。默认为 default
tag="${tag:-default}"

# sing-box
echo "--------------------------------------------------"
echo "simple-vless 啟動中..."
echo "--------------------------------------------------"
echo "【 sing-box 】"
# 如果 UUID 未提供，随机生成一个
if [ -z "$uuid" ]; then
    uuid=$(sing-box generate uuid)
fi
# 配置文件
cat > 0.json <<EOF
{
  "log": { "disabled": false, "level": "warn", "timestamp": true },
  "inbounds": [
    { "type": "vless", "tag": "proxy", "listen": "::", "listen_port": ${port},
      "users": [ { "uuid": "${uuid}", "flow": "" } ],
      "transport": { "type": "ws", "path": "/${uuid}", "max_early_data": 2048, "early_data_header_name": "Sec-WebSocket-Protocol" }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
EOF
echo "sing-box 配置已部署"
# 啟動 sing-box 并後台運行
# 日誌重定向到 /dev/null
nohup sing-box run -c 0.json > /dev/null 2>&1 &
sleep 3 # 确保 sing-box 成功啟動

# cf
echo "--------------------------------------------------"
echo "【 Cloudflared 】"
TUNNEL_CONNECTED=false # 隧道連接狀態
# 固定隧道模式
if [ -n "$token" ] && [ -n "$domain" ]; then
    TUNNEL_MODE="固定隧道"
    echo "檢測到 token 和 domain 已配置，使用固定隧道模式"
    # 啟動固定隧道
    nohup cloudflared tunnel --no-autoupdate run --token "${token}" > ./0.log 2>&1 &
    echo "等待隧道連接..."
    for attempt in $(seq 1 15); do
        sleep 2
        if grep -q -E "Registered tunnel connection|Connected to .*, an Argo Tunnel an edge" ./0.log; then
            TUNNEL_CONNECTED=true # 成功連接固定隧道
            break
        fi
    done
# 臨時隧道模式
else
    TUNNEL_MODE="臨時隧道"
    echo "檢測到 token 或/和 domain 未配置，使用臨時隧道模式"
    # 啓動臨時隧道
    nohup cloudflared tunnel --url http://localhost:${port} --edge-ip-version auto --no-autoupdate --protocol http2 > ./0.log 2>&1 &
    echo "等待臨時隧道..."
    for attempt in $(seq 1 15); do
        sleep 2
        TEMP_TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare.com' ./0.log | head -n 1)
        if [ -n "$TEMP_TUNNEL_URL" ]; then
            domain=$(echo "$TEMP_TUNNEL_URL" | awk -F'//' '{print $2}')
            TUNNEL_CONNECTED=true # 成功連接臨時隧道
            break
        fi
    done
fi
if [ "$TUNNEL_CONNECTED" = "true" ]; then
    echo "$TUNNEL_MODE連接成功！"
    echo "--------------------------------------------------"
    echo "simple-vless 啟動成功"

# node
    echo "--------------------------------------------------"
    echo "【 節點鏈接 】"
    echo "⭐ 複製下方鏈接，粘貼到客戶端使用"
    for node_info in \
        "www.visa.com.tw:443:vTW" \
        "www.visa.com.hk:2053:vHK" \
        "www.visa.com.br:8443:vBR" \
        "www.visaeurope.ch:443:vCH" \
        "usa.visa.com:2053:vUS" \
        "icook.hk:8443:iHK" \
        "icook.tw:443:iTW"
    do
        OLDIFS=$IFS; IFS=':'; set -- $node_info; SERVER_ADDRESS="$1"; SERVER_PORT="$2"; SERVER_SUFFIX="$3"; IFS=$OLDIFS
		echo "    vless://${uuid}@${SERVER_ADDRESS}:${SERVER_PORT}?encryption=none&security=tls&sni=${domain}&host=${domain}&fp=chrome&type=ws&path=%2F${uuid}%3Fed%3D2048#${tag}_simple-vless_${SERVER_SUFFIX}"
    done
    echo "--------------------------------------------------"

# log
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