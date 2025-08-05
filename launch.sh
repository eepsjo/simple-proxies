#!/bin/sh

# 腳本說明：此腳本用於啟動一個基於 VLESS + Reality 協議的 sing-box 伺服器。
#
# 重要提示：此腳本需要 sing-box v1.8.0 或更高版本才能正常運作。
# 已將舊的 "handshake_server" 欄位更新為 "dest_override"，以修復最新的錯誤。

echo "--------------------------------------------------"
echo "simple-reality 啟動中..."
echo "--------------------------------------------------"

# ========== 1. 從環境變數讀取配置或使用預設值 ==========
# 檢查並顯示所有關鍵環境變數
echo "正在檢查環境變數..."
echo "domain: ${domain:-未設定，將使用預設值 www.apple.com}"
echo "SNI_DOMAIN: ${SNI_DOMAIN:-未設定，將使用預設值 ${domain}}"
echo "location: ${location:-未設定，將使用預設值 default}"
echo "uuid: ${uuid:-未設定，將自動生成}"

LISTEN_PORT=443
HANDSHAKE_PORT=443
domain="${domain:-www.apple.com}"
SNI_DOMAIN="${SNI_DOMAIN:-$domain}"
location="${location:-default}"
uuid="${uuid}"

echo "啟動配置："
echo "監聽端口: ${LISTEN_PORT}"
echo "偽裝目標: ${domain}"
echo "SNI 域名: ${SNI_DOMAIN}"
echo "節點位置: ${location}"

# ========== 2. 生成 UUID 和 Reality 密鑰對 ==========
if [ -z "$uuid" ]; then
    uuid=$(sing-box generate uuid)
    echo "環境變數中未提供 uuid，已生成新的 UUID: ${uuid}"
else
    echo "已使用環境變數中提供的 uuid: ${uuid}"
fi

echo "正在生成 Reality 密鑰對..."
REALITY_KEYS=$(sing-box generate reality-keypair)
SERVER_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key" | awk '{print $NF}')
SERVER_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key" | awk '{print $NF}')
echo "Reality 私鑰已生成。"

# ========== 3. 創建 sing-box 配置檔案 (config.json) ==========
echo "正在部署 sing-box 配置..."
# 注意：已將 "handshake_server" 更新為 "dest_override"。
cat > config.json <<EOF
{
  "log": { 
    "disabled": false,
    "level": "warn",
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
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "reality": {
          "enabled": true,
          "dest_override": "${domain}:${HANDSHAKE_PORT}",
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
echo "UUID: ${uuid}"
echo "公鑰: ${SERVER_PUBLIC_KEY}"
echo "偽裝目標 (Handshake Server): ${domain}"
echo "節點名稱: ${location}_simple-reality"
echo "--------------------------------------------------"
echo "【 VLESS URI - 可直接複製使用 】"
VLESS_URI="vless://${uuid}@<您的伺服器 IP>:${LISTEN_PORT}?security=reality&encryption=none&pbk=${SERVER_PUBLIC_KEY}&fp=chrome&sni=${SNI_DOMAIN}&sid=&type=tcp&flow=xtls-rprx-vision#${location}_simple-reality"
echo ""
echo "請替換URI中的 <您的伺服器 IP> 為您的實際 IP 或域名。"
echo "您可以複製此 URI 並在客戶端中使用。"
echo ""
echo "$VLESS_URI"
echo "--------------------------------------------------"

echo "【 日誌 】"
tail -f sing-box.log
