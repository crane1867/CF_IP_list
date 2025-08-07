#!/usr/bin/env bash
set -e

# ===== 配置：请替换为你的 GitHub 仓库地址（raw 访问） =====
GITHUB_RAW_BASE="https://raw.githubusercontent.com/crane1867/CF_IP_list/main"

# 安装目录
TARGET_DIR="/root/cf-ip-updater"

echo "==> 创建安装目录: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 下载核心文件
for file in cf_ip_update.py .env.example README.md; do
  echo "==> 下载 $file"
  curl -fsSL "$GITHUB_RAW_BASE/$file" -o "$file"
done

# 1. 检测系统并安装 Python3 + pip
echo "==> 检测系统包管理器"
if [ -x "$(command -v apt-get)" ]; then
  pkg="python3 python3-venv python3-pip"
  sudo apt-get update
  sudo apt-get install -y $pkg
elif [ -x "$(command -v yum)" ]; then
  pkg="python3 python3-venv python3-pip"
  sudo yum install -y $pkg
else
  echo "Unsupported OS. 请手动安装 Python 3、python3-venv 和 pip" >&2
  exit 1
fi

# 2. 创建并激活虚拟环境
echo "==> 创建虚拟环境"
python3 -m venv venv
source venv/bin/activate

# 3. 安装 Python 依赖
echo "==> 安装 Python 依赖"
pip install --upgrade pip
pip install -r requirements.txt

# 4. 生成 .env（如已存在则跳过）
if [ -f .env ]; then
  echo "==> .env 已存在，跳过生成"
else
  cp .env.example .env
  echo "==> 已复制 .env.example -> .env，请编辑 .env 填写配置信息"
fi

# 5. 配置定时任务（默认每小时第 0 分执行）
CRON_SCHEDULE=$(grep "^CRON_SCHEDULE" .env | cut -d'=' -f2- | tr -d '"')
CRON_CMD="cd $TARGET_DIR && source $TARGET_DIR/venv/bin/activate && python $TARGET_DIR/cf_ip_update.py"
echo "==> 配置 crontab: $CRON_SCHEDULE"
( crontab -l | grep -Fv "cf_ip_update.py" ; echo "$CRON_SCHEDULE $CRON_CMD" ) | crontab -

echo "==> 安装完成！"
echo "   - 编辑 $TARGET_DIR/.env，完成配置后脚本会按计划自动运行。"
echo "   - 可通过命令 'crontab -l' 查看当前定时任务。"
