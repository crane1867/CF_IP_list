#!/bin/bash

echo "=== Cloudflare IP列表更新器 卸载助手 ==="

# 删除Python脚本
if [ -f /root/cf_update_ip_list.py ]; then
    rm /root/cf_update_ip_list.py
    echo "已删除 /root/cf_update_ip_list.py"
else
    echo "未找到Python脚本，无需删除。"
fi

# 删除日志文件
if [ -f /root/cf_updater.log ]; then
    rm /root/cf_updater.log
    echo "已删除日志文件 /root/cf_updater.log"
fi

# 清理 crontab 定时任务
crontab -l | grep -v "cf_ip_update.py" | crontab -
echo "已从crontab移除自动更新任务。"

# 卸载Python requests库
if pip3 show requests >/dev/null 2>&1; then
    pip3 uninstall -y requests
    echo "已卸载 Python requests库。"
else
    echo "requests库未安装或已被删除。"
fi

# 提示是否卸载pip
read -p "是否一并卸载 python3-pip （除非不再需要 Python，请谨慎选择）？(y/n): " UNINSTALL_PIP
if [[ "$UNINSTALL_PIP" == "y" ]]; then
    apt remove -y python3-pip
    echo "已卸载 python3-pip。"
else
    echo "保留 python3-pip。"
fi

echo "✅ 完全卸载完成，系统已清理干净。"
