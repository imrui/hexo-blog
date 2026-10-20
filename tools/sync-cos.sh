#!/usr/bin/env bash
#
# 将 assets/images/ 同步到腾讯云 COS，供 maxcdn.hjhblr.com 回源。
#
# 目录映射（本地与远端结构镜像，无路径转换逻辑）：
#   assets/images/posts/<上传日期>-<图组slug>/NN.webp
#     -> cos://<BUCKET>/blog/posts/<上传日期>-<图组slug>/NN.webp
#     -> https://maxcdn.hjhblr.com/blog/posts/<上传日期>-<图组slug>/NN.webp
#
# 依赖 coscmd：pipx install coscmd（或 pip install coscmd）
#
# 配置（统一 BLOG_COS_ 前缀，建议设为系统环境变量，见 README「插图上传」）：
#   BLOG_COS_SECRET_ID    API 密钥 SecretId
#   BLOG_COS_SECRET_KEY   API 密钥 SecretKey
#   BLOG_COS_BUCKET       存储桶，如 your-bucket-1250000000
#   BLOG_COS_REGION       地域，如 ap-guangzhou
#
# 用法：
#   bash tools/sync-cos.sh                                  # 增量同步全部图片
#   bash tools/sync-cos.sh posts/2026-10-20-xxx             # 只同步某个图组
#   bash tools/sync-cos.sh --dry [posts/2026-10-20-xxx]     # 仅列出本地文件与对应 URL
#
# 密钥只从环境变量读取，不写入仓库；coscmd 配置写入临时文件，退出即删除。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CDN="https://maxcdn.hjhblr.com"
DEST="/blog"

DRY=0
if [ "${1:-}" = "--dry" ]; then
  DRY=1
  shift
fi
SUB="${1:-}"
SUB="${SUB#/}"
SUB="${SUB%/}"

SRC="$ROOT/assets/images${SUB:+/$SUB}"
if [ ! -d "$SRC" ]; then
  echo "错误：源目录不存在 $SRC" >&2
  exit 1
fi

url_of() {
  echo "$CDN$DEST/${1#"$ROOT/assets/images/"}"
}

echo "源目录 : $SRC"
echo "目标   : $CDN$DEST${SUB:+/$SUB}"
echo "文件数 : $(find "$SRC" -type f | wc -l)"
echo "总大小 : $(du -sh "$SRC" | cut -f1)"
echo

if [ "$DRY" = 1 ]; then
  echo "--- dry-run：本地文件及对应 URL（实际上传时跳过远端已一致的文件）---"
  find "$SRC" -type f | sort | while IFS= read -r f; do
    echo "  $(url_of "$f")"
  done
  exit 0
fi

for v in BLOG_COS_SECRET_ID BLOG_COS_SECRET_KEY BLOG_COS_BUCKET BLOG_COS_REGION; do
  if [ -z "${!v:-}" ]; then
    echo "错误：环境变量 $v 未设置（WSL 中读取 Windows 变量需配置 WSLENV，见 README）" >&2
    exit 1
  fi
done

if ! command -v coscmd >/dev/null 2>&1; then
  echo "错误：未找到 coscmd，请先安装：pipx install coscmd（或 pip install coscmd）" >&2
  exit 1
fi

CONF="$(mktemp)"
trap 'rm -f "$CONF"' EXIT
chmod 600 "$CONF"

coscmd -c "$CONF" config \
  -a "$BLOG_COS_SECRET_ID" \
  -s "$BLOG_COS_SECRET_KEY" \
  -b "$BLOG_COS_BUCKET" \
  -r "$BLOG_COS_REGION"

# -r 递归，-s 即 --sync：仅上传与远端 CRC 不一致的文件，可重复执行
coscmd -c "$CONF" upload -rs "$SRC/" "$DEST${SUB:+/$SUB}/"

echo
echo "同步完成。抽查最近修改的文件："
find "$SRC" -type f -printf '%T@ %p\n' | sort -rn | head -3 | cut -d' ' -f2- | while IFS= read -r f; do
  url="$(url_of "$f")"
  code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$url" || echo "000")
  echo "  [$code] $url"
done
