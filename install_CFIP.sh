#!/bin/bash

echo "=== Cloudflare IP更新器 安装助手 ==="
echo "请按照提示输入配置信息。"

read -p "Cloudflare API Token: " input
CF_API_TOKEN=$(echo "$input" | tr -d '\r')

while true; do
    read -p "Cloudflare Account ID (必须是32位字符，不是邮箱): " input
    ACCOUNT_ID=$(echo "$input" | tr -d '\r')
    if [[ ${#ACCOUNT_ID} -eq 32 ]]; then
        break
    else
        echo "⚠️ 输入错误：Account ID 应该是32位字符，请重新输入。"
    fi
done

while true; do
    read -p "Cloudflare List ID (必须是32位字符): " input
    LIST_ID=$(echo "$input" | tr -d '\r')
    if [[ ${#LIST_ID} -eq 32 ]]; then
        break
    else
        echo "⚠️ 输入错误：List ID 应该是32位字符，请重新输入。"
    fi
done

read -p "要监控的域名（用空格隔开，例如: a.com b.com c.com ）: " input
DOMAIN_INPUT=$(echo "$input" | tr -d '\r')

read -p "Telegram Bot Token: " input
TELEGRAM_BOT_TOKEN=$(echo "$input" | tr -d '\r')

read -p "Telegram Chat ID: " input
TELEGRAM_CHAT_ID=$(echo "$input" | tr -d '\r')

# 自动格式化域名列表为Python数组
DOMAIN_NAMES_LIST=$(echo "$DOMAIN_INPUT" | sed "s/ /', '/g")
DOMAIN_NAMES="['$DOMAIN_NAMES_LIST']"

SCRIPT_PATH="/root/cf_update_ip_list.py"
LOG_PATH="/root/cf_updater.log"

# 安装依赖
echo "正在安装Python和requests库..."
apt update && apt install -y python3 python3-pip
pip3 install requests --break-system-packages

# 下载 Python 脚本模板
wget -O /tmp/cf_update_ip_list_template.py https://raw.githubusercontent.com/crane1867/CF_IP_list/main/cf_update_ip_list.py

# 替换模板变量
sed -e "s|{{CF_API_TOKEN}}|$CF_API_TOKEN|g" \
    -e "s|{{ACCOUNT_ID}}|$ACCOUNT_ID|g" \
    -e "s|{{LIST_ID}}|$LIST_ID|g" \
    -e "s|{{DOMAIN_NAMES}}|$DOMAIN_NAMES|g" \
    -e "s|{{TELEGRAM_BOT_TOKEN}}|$TELEGRAM_BOT_TOKEN|g" \
    -e "s|{{TELEGRAM_CHAT_ID}}|$TELEGRAM_CHAT_ID|g" \
    -e "s|{{LOG_FILE}}|$LOG_PATH|g" /tmp/cf_update_ip_list_template.py > $SCRIPT_PATH

chmod +x $SCRIPT_PATH

echo "✅ Python 脚本已配置完成：$SCRIPT_PATH"
echo "可以通过以下命令测试运行："
echo "python3 $SCRIPT_PATH"

read -p "是否设置自动运行（每10分钟）？(y/n): " AUTORUN
if [[ "$AUTORUN" == "y" ]]; then
    (crontab -l 2>/dev/null; echo "*/10 * * * * /usr/bin/python3 $SCRIPT_PATH >> /root/cf_cron.log 2>&1") | crontab -
    echo "✅ 已添加到crontab，10分钟自动更新一次。"
else
    echo "⏩ 跳过定时任务配置。"
fi

echo "✅ 安装完成！"
