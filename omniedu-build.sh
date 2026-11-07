#!/usr/bin/env bash
# omniedu-build.sh - 一键触发 GitHub Actions 构建并下载 GGUF
# 用法: ./omniedu-build.sh [quant_type] [repo_owner/repo_name]
# 例:   ./omniedu-build.sh Q4_K_M chenyuanyuan/omniedu-gguf-builder

set -euo pipefail

QUANT_TYPE="${1:-Q3_K_M}"
REPO="${2:-jiaochh-beep/omniedu-gguf-builder}"
WORKFLOW="build-omniedu-4b.yml"

echo "🚀 触发 GitHub Actions 构建: $REPO -> $WORKFLOW (quant: $QUANT_TYPE)"

# 触发 workflow
RUN_ID=$(gh api -X POST "repos/$REPO/actions/workflows/$WORKFLOW/dispatches" \
  -f ref=main \
  -f "inputs[quant_type]=$QUANT_TYPE" \
  --jq '.id // empty' 2>/dev/null || echo "")

if [[ -z "$RUN_ID" ]]; then
  # 兼容旧版 gh，用 run id 查找
  sleep 3
  RUN_ID=$(gh run list -R "$REPO" -w "$WORKFLOW" --limit 1 --json databaseId --jq '.[0].databaseId')
fi

echo "📋 Workflow Run ID: $RUN_ID"
echo "⏳ 等待构建完成（约 15-25 分钟）..."

# 等待完成
gh run watch "$RUN_ID" -R "$REPO"

# 获取结果
CONCLUSION=$(gh run view "$RUN_ID" -R "$REPO" --json conclusion --jq '.conclusion')
if [[ "$CONCLUSION" != "success" ]]; then
  echo "❌ 构建失败: $CONCLUSION"
  gh run view "$RUN_ID" -R "$REPO" --log-failed
  exit 1
fi

echo "✅ 构建成功，下载产物..."

# 下载 release 资产
TAG=$(gh release list -R "$REPO" --limit 1 --json tagName --jq '.[0].tagName')
gh release download "$TAG" -R "$REPO" --pattern "*.gguf" --dir ~/models

echo "📦 模型已下载到 ~/models/"
ls -lh ~/models/Omni-Edu-4B-*.gguf

echo ""
echo "🚀 启动推理服务:"
echo "  llama-server -m ~/models/Omni-Edu-4B-${QUANT_TYPE}.gguf \\"
echo "    --host 0.0.0.0 --port 8080 -c 4096 -ngl 0 --no-mmap --jinja-template chatml"