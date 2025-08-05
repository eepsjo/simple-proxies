#!/bin/sh

echo "--------------------------------------------------"
echo "simple-reality 啟動中..."
echo "--------------------------------------------------"

# sing-box
echo "【 sing-box 】"
EFFECTIVE_UUID=""
if [ -n "$uuid" ]; then
    # 如果用戶提供了 UUID
    EFFECTIVE_UUID="$uuid"
    echo "使用提供的 UUID: ${EFFECTIVE_UUID}"
else
    # 自動生成 UUID
    EFFECTIVE_UUID=$(sing-box generate uuid)
    echo "未提供 UUID，自動生成: ${EFFECTIVE_UUID}"
fi
REALITY_DEST="${dest:-www.apple.com}" # Reality 的目標網站 (dest)
if [ -n "$shortId" ]; then
    # 如果用戶提供了 shortId
    REALITY_SHORT_ID="$shortId"
    echo "使用提供的 shortId: ${REALITY_SHORT_ID}"
else
    # 生成一個隨機的 8 字節 shortId (16 個 16 進制字符)
    REALITY_SHORT_ID=$(sing-box generate rand 8 --hex)
    echo "未提供 shortId，自動生成: ${REALITY_SHORT_ID}"
fi
echo "生成 Reality 金鑰對..."
# sing-box generate reality-keypair 會同時輸出私鑰和公鑰
REALITY_KEYPAIR_OUTPUT=$(sing-box generate reality-keypair)
REALITY_PRIVATE_KEY=$(echo "$REALITY_KEYPAIR_OUTPUT" | grep "PrivateKey:" | awk '{print $2}')
REALITY_PUBLIC_KEY=$(echo "$REALITY_KEYPAIR_OUTPUT" | grep "PublicKey:" | awk '{print $2}')
echo "Reality 金鑰對已生成"
cat > 0.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 443,
      "users": [
        {
          "uuid": "${EFFECTIVE_UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${REALITY_DEST}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${REALITY_DEST}",
            "server_port": 443
          },
          "private_key": "${REALITY_PRIVATE_KEY}",
          "short_id": "${REALITY_SHORT_ID}"
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
echo "sing-box 配置已部署"
nohup sing-box run -c 0.json > ./0.log 2>&1 &
sleep 2 # 給服務一點時間啟動

# output
echo "--------------------------------------------------"
echo "simple-reality 啟動成功"
echo "--------------------------------------------------"
echo "【 節點鏈接 】"
echo "複製下面的模板，然後將其中 'example.com' 部分替換為公共地址"
location="${location:-default}"
echo "模板:"
echo "    vless://${EFFECTIVE_UUID}@example.com:443?security=reality&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sni=${REALITY_DEST}&sid=${REALITY_SHORT_ID}&type=tcp&flow=xtls-rprx-vision#${location}_simple-reality"
echo "--------------------------------------------------"
echo "【 日誌 】"
tail -f ./0.log
