#!/usr/bin/env bash
#
# 将 assets/images/ 同步到腾讯云 COS，供 maxcdn.hjhblr.com 回源。
#
# 目录映射（本地与远端结构镜像，无路径转换逻辑）：
#   assets/images/posts/<上传日期>-<图组slug>/NN.jpg
#     -> cos://<BUCKET>/blog/posts/<上传日期>-<图组slug>/NN.jpg
#     -> https://maxcdn.hjhblr.com/blog/posts/<上传日期>-<图组slug>/NN.jpg
#
# 依赖 coscmd：pip install coscmd
#
# 用法：
#   export COS_SECRET_ID=xxx
#   export COS_SECRET_KEY=xxx
#   export COS_BUCKET=your-bucket-1250000000
#   export COS_REGION=ap-guangzhou
#   bash scripts/sync-cos.sh          # 增量同步
#   bash scripts/sync-cos.sh --dry    # 仅列出将要上传的文件
#
# 密钥只从环境变量读取，不写入仓库。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/assets/images"
DEST="/blog"
CDN="https://maxcdn.hjhblr.com"

for v in COS_SECRET_ID COS_SECRET_KEY COS_BUCKET COS_REGION; do
  if [ -z "${!v:-}" ]; then
    echo "错误：环境变量 $v 未设置" >&2
    exit 1
  fi
done

if [ ! -d "$SRC" ]; then
  echo "错误：源目录不存在 $SRC" >&2
  exit 1
fi

if ! command -v coscmd >/dev/null 2>&1; then
  echo "错误：未找到 coscmd，请先安装：pip install coscmd" >&2
  exit 1
fi

echo "源目录 : $SRC"
echo "目标   : cos://$COS_BUCKET$DEST  ($COS_REGION)"
echo "文件数 : $(find "$SRC" -type f | wc -l)"
echo "总大小 : $(du -sh "$SRC" | cut -f1)"
echo

if [ "${1:-}" = "--dry" ]; then
  echo "--- dry-run：将要同步的文件 ---"
  find "$SRC" -type f | while IFS= read -r f; do
    echo "  ${f#$SRC/}  ->  $CDN$DEST/${f#$SRC/}"
  done
  exit 0
fi

coscmd config \
  -a "$COS_SECRET_ID" \
  -s "$COS_SECRET_KEY" \
  -b "$COS_BUCKET" \
  -r "$COS_REGION"

# --sync 为增量：仅上传本地与远端 CRC 不一致的文件，可重复执行
coscmd upload -rs --sync "$SRC/" "$DEST/"

echo
echo "同步完成。抽查："
find "$SRC" -type f | head -3 | while IFS= read -r f; do
  url="$CDN$DEST/${f#$SRC/}"
  code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$url" || echo "000")
  echo "  [$code] $url"
done
