#!/bin/bash

# HyCrypt Code Formatter Script
# This script formats all Go files in the project using go fmt

set -e

echo "🚀 正在格式化 Go 代码..."

# Change to project root directory
cd "$(dirname "$0")/.."

# Format all Go files recursively
echo "📝 使用 go fmt 格式化所有 .go 文件..."
find . -name "*.go" -type f -exec go fmt {} \;

# Alternative: Use goimports if available (more comprehensive formatting)
if command -v goimports >/dev/null 2>&1; then
    echo "📦 使用 goimports 优化 import 语句..."
    find . -name "*.go" -type f -exec goimports -w {} \;
else
    echo "💡 提示: 安装 goimports 可获得更好的格式化效果："
    echo "   go install golang.org/x/tools/cmd/goimports@latest"
fi

# Run go mod tidy to clean up dependencies
echo "🧹 清理依赖项..."
go mod tidy

echo "✅ 代码格式化完成！"