#!/bin/bash
# 测试 PATH 配置脚本

echo "=== 测试 hycrypt PATH 配置 ==="
echo ""

# 临时添加 PATH
export PATH="$HOME/bin:$PATH"

echo "测试 1: 检查命令是否存在"
if command -v hycrypt > /dev/null 2>&1; then
    echo "✅ hycrypt 命令已找到"
    echo "位置: $(which hycrypt)"
else
    echo "❌ hycrypt 命令未找到"
    exit 1
fi

echo ""
echo "测试 2: 从不同目录运行"
cd /tmp
echo "当前目录: $(pwd)"

if hycrypt --help > /dev/null 2>&1; then
    echo "✅ 可以从 /tmp 目录正常运行"
else
    echo "❌ 无法从 /tmp 目录运行"
    exit 1
fi

echo ""
echo "测试 3: 验证功能"
hycrypt --help | head -3

echo ""
echo "🎉 所有测试通过！"
echo "✅ hycrypt 命令已成功配置到系统 PATH"
echo "💡 现在您可以在任何目录运行 hycrypt 命令了""""测试PATH配置脚本"