#!/bin/bash

echo "=== Cloudflare IP更新器 安装助手 ==="
echo "请按照提示输入配置信息。"

read -p "Cloudflare API Token: " CF_API_TOKEN
read -p "Cloudflare Account ID: " ACCOUNT_ID
read -p "Cloudflare List ID: " LIST_ID
read -p "要监控的域名（用空格隔开，例如: a.com b.com c.com ）: " DOMAIN_INPUT
read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID

SCRIPT_PATH="/root/cf_update_ip_list.py"
LOG_PATH="/root/cf_updater.log"

# 安装Python和requests
echo "正在安装Python和requests库..."
apt update && apt install -y python3 python3-pip
pip3 install requests --upgrade

# 创建Python脚本
cat <<EOF > /root/cf_update_ip_list.py
import requests
import socket
import ipaddress
import time
import datetime

CF_API_TOKEN = '${CF_API_TOKEN}'
ACCOUNT_ID = '${ACCOUNT_ID}'
LIST_ID = '${LIST_ID}'
DOMAIN_NAMES = ${DOMAIN_INPUT.split()}

TELEGRAM_BOT_TOKEN = '${TELEGRAM_BOT_TOKEN}'
TELEGRAM_CHAT_ID = '${TELEGRAM_CHAT_ID}'

LOG_FILE = '${/root/cf_update_ip_list.log}'

CF_API_URL = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/rules/lists/{LIST_ID}/items"
HEADERS = {
    "Authorization": f"Bearer {CF_API_TOKEN}",
    "Content-Type": "application/json"
}

def log(message):
    now = datetime.datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    with open(LOG_FILE, 'a') as f:
        f.write(f"{now} {message}\\n")
    print(f"{now} {message}")

def notify_telegram(message):
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        payload = {'chat_id': TELEGRAM_CHAT_ID, 'text': f"[CF IP更新器] {message}"}
        requests.post(url, data=payload, timeout=10)
    except Exception as e:
        log(f"Telegram通知失败：{e}")

def resolve_ips(domain):
    ipv4_list, ipv6_list = [], []
    try:
        for info in socket.getaddrinfo(domain, None):
            family, _, _, _, sockaddr = info
            ip = sockaddr[0]
            if family == socket.AF_INET:
                ipv4_list.append(ip)
            elif family == socket.AF_INET6:
                ipv6_list.append(ip)
    except Exception as e:
        log(f"解析 {domain} 时出错: {e}")
        notify_telegram(f"解析 {domain} 时出错: {e}")
    return ipv4_list, ipv6_list

def format_ipv6_to_cidr(ipv6):
    try:
        network = ipaddress.IPv6Network(ipv6 + '/64', strict=False)
        return str(network)
    except Exception as e:
        log(f"IPv6转换失败: {e}")
        return None

def build_ip_list(domains):
    final_ips = []
    for domain in domains:
        ipv4s, ipv6s = resolve_ips(domain)
        final_ips.extend(ipv4s)
        final_ips.extend([format_ipv6_to_cidr(ip) for ip in ipv6s if format_ipv6_to_cidr(ip)])
    return final_ips

def upload_to_cloudflare(ip_list):
    items = [{"ip": ip} for ip in ip_list]
    try:
        delete = requests.delete(CF_API_URL, headers=HEADERS)
        if not delete.ok:
            log(f"删除旧列表失败: {delete.text}")
            notify_telegram(f"Cloudflare删除旧列表失败：{delete.text}")
            return

        batch_size = 1000
        for i in range(0, len(items), batch_size):
            batch = items[i:i + batch_size]
            response = requests.post(CF_API_URL, headers=HEADERS, json={"items": batch})
            if response.ok:
                log(f"上传第 {i//batch_size + 1} 批成功（{len(batch)}项）")
            else:
                log(f"上传第 {i//batch_size + 1} 批失败: {response.text}")
                notify_telegram(f"Cloudflare上传失败：{response.text}")
    except Exception as e:
        log(f"上传IP列表时出现异常：{e}")
        notify_telegram(f"上传IP列表时异常：{e}")

def main():
    log("开始运行 Cloudflare IP列表更新...")
    ip_list = build_ip_list(DOMAIN_NAMES)
    log(f"解析完成，共 {len(ip_list)} 个IP，准备上传。")
    upload_to_cloudflare(ip_list)
    log("任务完成。")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"主程序异常: {e}")
        notify_telegram(f"主程序遇到严重错误：{e}")
EOF

chmod +x $SCRIPT_PATH

echo "脚本已生成：cf_update_ip_list.py"
echo "可以通过以下命令测试："
echo "python3 cf_update_ip_list.py"

read -p "是否需要设置自动运行（每10分钟）？(y/n): " AUTORUN
if [[ "\$AUTORUN" == "y" ]]; then
    (crontab -l 2>/dev/null; echo "*/10 * * * * /usr/bin/python3 cf_update_ip_list.py >> /root/cf_cron.log 2>&1") | crontab -
    echo "已添加定时任务。"
else
    echo "跳过定时任务配置。"
fi

echo "✅ 安装完成！"
