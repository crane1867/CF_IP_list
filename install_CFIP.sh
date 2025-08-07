#!/usr/bin/env bash
set -e

# 1. 检测系统并安装 Python3 + pip
if [ -x "$(command -v apt-get)" ]; then
  pkg="python3 python3-pip"
  sudo apt-get update
  sudo apt-get install -y $pkg
elif [ -x "$(command -v yum)" ]; then
  pkg="python3 python3-pip"
  sudo yum install -y $pkg
else
  echo "Unsupported OS. Please install Python 3 & pip manually." >&2
  exit 1
fi

# 2. 设置虚拟环境（可选）
python3 -m venv venv
source venv/bin/activate

# 3. 安装 Python 依赖
pip install --upgrade pip
pip install -r requirements.txt

# 4. 生成 .env
if [ -f .env ]; then
  echo ".env already exists, skipped"
else
  cp .env.example .env
  echo "请编辑 .env 文件，填写你的 CF_API_TOKEN、IP_LIST_ID、DOMAIN_LIST、TG_BOT_TOKEN、TG_CHAT_ID 等"
fi

# 5. 添加到 crontab
croncmd="cd $(pwd) && source $(pwd)/venv/bin/activate && python cf_ip_update.py"
cronjob="${CRON_SCHEDULE:-*/5 * * * *} ${croncmd}"
( crontab -l | grep -Fv "cf_ip_update.py" ; echo "$cronjob" ) | crontab -

echo "安装完成，脚本已加入定时任务。"
