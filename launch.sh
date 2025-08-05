#!/bin/sh

# 腳本說明：此腳本用於啟動一個基於 VLESS + Reality 協議的 sing-box 伺服器。
# 它會從 Docker 環境變數中讀取配置，如果沒有設定，則使用預設值。
# 它會自動生成 UUID 和 Reality 密鑰對，並建立 sing-box 配置，然後列印出客戶端所需的配置資訊。
# 啟動腳本將由 setup.sh 自動調用。

echo "--------------------------------------------------"
echo "simple-reality 啟動中..."
echo "--------------------------------------------------"

# ========== 1. 從環境變數讀取配置或使用預設值 ==========
# 可用的變數：
# HANDSHAKE_SERVER: 偽裝目標網站，預設值為 www.apple.com
# SNI_DOMAIN: TLS SNI 域名，預設值與 HANDSHAKE_SERVER 相同
# LOCATION: 節點位置或名稱，預設值為 default
# UUID: 客戶端身份驗證 UUID，如果未提供則自動生成

LISTEN_PORT=443
HANDSHAKE_PORT=443
HANDSHAKE_SERVER="${HANDSHAKE_SERVER:-www.apple.com}"
SNI_DOMAIN="${SNI_DOMAIN:-$HANDSHAKE_SERVER}"
LOCATION="${LOCATION:-default}"
PROVIDED_UUID="${UUID}"

echo "啟動配置："
echo "監聽端口: ${LISTEN_PORT}"
echo "偽裝目標: ${HANDSHAKE_SERVER}"
echo "SNI 域名: ${SNI_DOMAIN}"
echo "節點位置: ${LOCATION}"


# ========== 2. 生成 UUID 和 Reality 密鑰對 ==========

# 如果沒有提供 UUID，則生成一個新的
if [ -z "$PROVIDED_UUID" ]; then
    EFFECTIVE_UUID=$(sing-box generate uuid)
    echo "環境變數中未提供 UUID，已生成新的 UUID: ${EFFECTIVE_UUID}"
else
    EFFECTIVE_UUID="$PROVIDED_UUID"
    echo "已使用環境變數中提供的 UUID: ${EFFECTIVE_UUID}"
fi

# 生成 Reality 密鑰對（私鑰和公鑰）
echo "正在生成 Reality 密鑰對..."
REALITY_KEYS=$(sing-box generate reality-keypair)
SERVER_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key" | awk '{print $NF}')
SERVER_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key" | awk '{print $NF}')
echo "Reality 私鑰已生成。"

# ========== 3. 創建 sing-box 配置檔案 (config.json) ==========
echo "正在部署 sing-box 配置..."
cat > config.json <<EOF
{
  "log": { 
    "disabled": false,
    "level": "error",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "proxy-in",
      "listen": "::",
      "listen_port": ${LISTEN_PORT},
      "users": [
        {
          "uuid": "${EFFECTIVE_UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "transport": {
        "type": "tls",
        "reality": {
          "enabled": true,
          "handshake_server": "${HANDSHAKE_SERVER}:${HANDSHAKE_PORT}",
          "private_key": "${SERVER_PRIVATE_KEY}",
          "server_names": [
            "${SNI_DOMAIN}"
          ]
        }
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

# ========== 4. 啟動 sing-box 服務 ==========
echo "正在啟動 sing-box 服務..."
nohup sing-box run -c config.json > sing-box.log 2>&1 &
sleep 2

if ! pgrep -f "sing-box run -c config.json" > /dev/null; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "sing-box 啟動失敗，請檢查日誌 sing-box.log"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    cat sing-box.log
    exit 1
fi

# ========== 5. 輸出客戶端配置資訊 ==========
echo "--------------------------------------------------"
echo "simple-reality 啟動成功！"
echo "--------------------------------------------------"
echo "【 客戶端配置資訊 】"
echo "⭐ 請複製以下資訊，填寫到您的客戶端設定中："
echo "伺服器端口: ${LISTEN_PORT}"
echo "UUID: ${EFFECTIVE_UUID}"
echo "公鑰: ${SERVER_PUBLIC_KEY}"
echo "偽裝目標 (Handshake Server): ${HANDSHAKE_SERVER}"
echo "節點名稱: ${LOCATION}_simple-reality"
echo "--------------------------------------------------"
echo "【 VLESS URI - 可直接複製使用 】"
VLESS_URI="vless://${EFFECTIVE_UUID}@<您的伺服器 IP>:${LISTEN_PORT}?security=reality&encryption=none&pbk=${SERVER_PUBLIC_KEY}&fp=chrome&sni=${SNI_DOMAIN}&sid=&type=tcp&flow=xtls-rprx-vision#${LOCATION}_simple-reality"
echo ""
echo "請替換URI中的 <您的伺服器 IP> 為您的實際 IP 或域名。"
echo "您可以複製此 URI 並在客戶端中使用。"
echo ""
echo "$VLESS_URI"
echo "--------------------------------------------------"

echo "【 日誌 】"
tail -f sing-box.log
