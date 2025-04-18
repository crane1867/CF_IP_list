#!/bin/bash

echo "=== Cloudflare IP更新器 安装助手 ==="
echo "请按照提示输入配置信息。"

read -p "Cloudflare API Token: " CF_API_TOKEN
read -p "Cloudflare Account ID: " ACCOUNT_ID
read -p "Cloudflare List ID: " LIST_ID
read -p "要监控的域名（用空格隔开，例如: a.com b.com c.com ）: " DOMAIN_INPUT
read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID

# 自动格式化域名列表
DOMAIN_NAMES_LIST=$(echo $DOMAIN_INPUT | sed "s/ /', '/g")
DOMAIN_NAMES="['$DOMAIN_NAMES_LIST']"

SCRIPT_PATH="/root/cf_update_ip_list.py"
LOG_PATH="/root/cf_updater.log"

# 安装依赖
echo "正在安装Python和requests库..."
apt update && apt install -y python3 python3-pip
pip3 install requests --break-system-packages

# 下载 Python 模板
wget -O /tmp/cf_update_ip_list_template.py https://raw.githubusercontent.com/crane1867/CF_IP_list/main/cf_update_ip_list.py

# 替换模板里的变量
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

# 定时任务选择
read -p "是否设置自动运行（每10分钟）？(y/n): " AUTORUN
if [[ "$AUTORUN" == "y" ]]; then
    (crontab -l 2>/dev/null; echo "*/10 * * * * /usr/bin/python3 $SCRIPT_PATH >> /root/cf_cron.log 2>&1") | crontab -
    echo "✅ 已添加到crontab，10分钟自动更新一次。"
else
    echo "⏩ 跳过定时任务配置。"
fi

echo "✅ 安装完成！"
