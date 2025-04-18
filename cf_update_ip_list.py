import requests
import socket
import ipaddress
import time
import datetime

# === Cloudflare配置 ===
CF_API_TOKEN = '{{CF_API_TOKEN}}'
ACCOUNT_ID = '{{ACCOUNT_ID}}'
LIST_ID = '{{LIST_ID}}'
DOMAIN_NAMES = {{DOMAIN_NAMES}}

# === Telegram通知配置 ===
TELEGRAM_BOT_TOKEN = '{{TELEGRAM_BOT_TOKEN}}'
TELEGRAM_CHAT_ID = '{{TELEGRAM_CHAT_ID}}'

# === 日志文件 ===
LOG_FILE = '{{LOG_FILE}}'

CF_API_URL = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/rules/lists/{LIST_ID}/items"
HEADERS = {
    "Authorization": f"Bearer {CF_API_TOKEN}",
    "Content-Type": "application/json"
}

def log(message):
    now = datetime.datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    with open(LOG_FILE, 'a') as f:
        f.write(f"{now} {message}\n")
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
    return list(set(final_ips))  # 去重，防止重复IP

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
