#!/usr/bin/env python3
import os
import sys
import logging
import requests
import dns.resolver
import ipaddress
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()
CF_ACCOUNT_ID = os.getenv("CF_ACCOUNT_ID")
CF_API_TOKEN   = os.getenv("CF_API_TOKEN")
IP_LIST_ID     = os.getenv("IP_LIST_ID")
DOMAIN_LIST    = os.getenv("DOMAIN_LIST", "").split(",")
TG_BOT_TOKEN   = os.getenv("TG_BOT_TOKEN")
TG_CHAT_ID     = os.getenv("TG_CHAT_ID")

if not all([CF_ACCOUNT_ID, CF_API_TOKEN, IP_LIST_ID, DOMAIN_LIST]):
    print("请确认 .env 中已配置 CF_ACCOUNT_ID, CF_API_TOKEN, IP_LIST_ID, DOMAIN_LIST")
    sys.exit(1)

# 日志配置
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler("cf_ip_update.log"), logging.StreamHandler()]
)

def resolve_ips(domain):
    """解析 A/AAAA 记录，IPv6 截断为 /64"""
    ips = []
    try:
        for rtype in ("A", "AAAA"):
            answers = dns.resolver.resolve(domain, rtype, lifetime=5)
            for r in answers:
                ip = ipaddress.ip_address(r.to_text())
                if ip.version == 6:
                    # 转成 /64 前缀
                    net = ipaddress.IPv6Network(f"{ip}/64", strict=False)
                    ips.append(str(net.network_address) + "/64")
                else:
                    ips.append(str(ip))
    except Exception as e:
        logging.error(f"{domain} 解析失败：{e}")
    return ips

def update_ip_list(ips):
    """调用 CF API 更新 IP 列表"""
    url = f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}/rules/lists/{IP_LIST_ID}/items"
    headers = {
        "Authorization": f"Bearer {CF_API_TOKEN}",
        "Content-Type": "application/json"
    }
    payload = {"items": [{"ip": ip, "comment": "updated by script"} for ip in sorted(set(ips))]}
    resp = requests.put(url, json=payload, headers=headers, timeout=10)
    data = resp.json()
    if not data.get("success"):
        raise RuntimeError(f"Cloudflare API Error: {data.get('errors')}")
    return len(payload["items"])

def send_telegram(msg):
    """发送 Telegram 通知"""
    if not TG_BOT_TOKEN or not TG_CHAT_ID:
        return
    url = f"https://api.telegram.org/bot{TG_BOT_TOKEN}/sendMessage"
    requests.post(url, json={"chat_id": TG_CHAT_ID, "text": msg})

def main():
    all_ips = []
    for d in DOMAIN_LIST:
        d = d.strip()
        if not d:
            continue
        ips = resolve_ips(d)
        logging.info(f"{d} -> {ips}")
        all_ips.extend(ips)

    try:
        count = update_ip_list(all_ips)
        msg = f"✅ 已更新 {count} 条 IP 到 Cloudflare 列表"
        logging.info(msg)
        send_telegram(msg)
    except Exception as e:
        err = f"❌ 更新 IP 列表失败：{e}"
        logging.error(err)
        send_telegram(err)
        sys.exit(1)

if __name__ == "__main__":
    main()
