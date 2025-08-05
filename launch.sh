#!/bin/sh

# =========================================
# sing-box VLESS + Reality 一鍵啟動腳本
# 功能：
# - 讀取/生成必要參數（UUID、公私鑰、short_id）
# - 動態生成 sing-box VLESS+Reality 配置檔
# - 啟動 sing-box 並輸出連接信息與日誌
# =========================================

echo "--------------------------------------------------"
echo "simple-reality 啟動中..."
echo "--------------------------------------------------"

# 1. 讀取環境變數或設置預設值
LISTEN_PORT=443
HANDSHAKE_PORT=443
domain="${domain:-www.apple.com}"           # 用於 Reality 偽裝握手和 SNI 的目標域名
location="${location:-default}"             # 節點標誌
uuid="${uuid}"                              # 用戶 UUID
short_id="${short_id}"                      # Reality short_id，小寫

echo "啟動配置："
echo "監聽端口: ${LISTEN_PORT}"
echo "偽裝目標與SNI: ${domain}"
echo "節點名稱: ${location}"
if [ -z "$short_id" ]; then
    echo "Reality short_id: (將自動生成)"
else
    echo "Reality short_id: ${short_id}"
fi

# 2. 自動生成 UUID 和 Reality 密鑰對（如未提供）
if [ -z "$uuid" ]; then
    uuid=$(sing-box generate uuid)
    echo "未提供 uuid，自動生成: ${uuid}"
else
    echo "使用提供的 uuid: ${uuid}"
fi

echo "生成 Reality 密鑰對..."
REALITY_KEYS=$(sing-box generate reality-keypair)
SERVER_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key" | awk '{print $NF}')
SERVER_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key" | awk '{print $NF}')
echo "Reality 公鑰: $SERVER_PUBLIC_KEY"

# 3. 生成符合要求的 short_id（8位16進制小寫字符串，如未提供）
if [ -z "$short_id" ]; then
    short_id=$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-8)
    echo "自動生成 short_id: ${short_id}"
else
    short_id=$(echo "$short_id" | tr '[:upper:]' '[:lower:]')
    echo "使用提供的 short_id: ${short_id}"
fi

# 4. 生成 sing-box 配置文件
echo "生成 sing-box 配置 (config.json)..."
cat > config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": ${LISTEN_PORT},
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${domain}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${domain}",
            "server_port": ${HANDSHAKE_PORT}
          },
          "private_key": "${SERVER_PRIVATE_KEY}",
          "short_id": [
            "${short_id}"
          ]
        },
        "alpn": [
          "h2",
          "http/1.1"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

# 5. 啟動 sing-box 並健康檢查
echo "啟動 sing-box 服務..."
nohup sing-box run -c config.json > sing-box.log 2>&1 &
sleep 2

if ! pgrep -f "sing-box run -c config.json" > /dev/null; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "sing-box 啟動失敗，請檢查日誌 sing-box.log"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    cat sing-box.log
    exit 1
fi

# 6. 輸出客戶端連接信息
echo "--------------------------------------------------"
echo "simple-reality 啟動成功！"
echo "--------------------------------------------------"
echo "【 客戶端配置資訊 】"
echo "伺服器端口: ${LISTEN_PORT}"
echo "UUID: ${uuid}"
echo "Reality 公鑰: ${SERVER_PUBLIC_KEY}"
echo "偽裝目標與SNI (Handshake Server): ${domain}"
echo "節點名稱: ${location}_simple-reality"
echo "Reality short_id: ${short_id}"
echo "--------------------------------------------------"
echo "【 VLESS URI - 可直接複製使用 】"
VLESS_URI="vless://${uuid}@<你的服務器IP>:${LISTEN_PORT}?security=reality&encryption=none&pbk=${SERVER_PUBLIC_KEY}&fp=chrome&sni=${domain}&sid=${short_id}&type=tcp&flow=xtls-rprx-vision#${location}_simple-reality"
echo ""
echo "請替換 <你的服務器IP> 為你的實際 IP 或域名。"
echo "${VLESS_URI}"
echo "--------------------------------------------------"

echo "【 sing-box 日誌 】"
tail -f sing-box.log
