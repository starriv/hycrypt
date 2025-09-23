#!/bin/bash
# hycrypt-py PATH 配置脚本
# 一键配置系统 PATH，可在任意目录运行 hycrypt 命令

echo "🚀 配置 hycrypt-py 系统 PATH..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 获取项目根目录（scripts 的父目录）
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📍 脚本目录: $SCRIPT_DIR"
echo "📍 项目目录: $PROJECT_DIR"

# 检查 hycrypt 文件是否存在
if [ ! -f "$PROJECT_DIR/hycrypt" ]; then
    echo "❌ 错误: hycrypt 文件不存在于项目目录"
    exit 1
fi

# 创建符号链接
echo "🔗 创建符号链接..."

# 优先尝试用户目录
if [ -d "$HOME/bin" ] || mkdir -p "$HOME/bin" 2>/dev/null; then
    ln -sf "$PROJECT_DIR/hycrypt" "$HOME/bin/hycrypt"
    echo "✅ 已安装到 $HOME/bin/hycrypt"
    
    # 添加到 PATH（如果不存在）
    if ! grep -q "export PATH=.*\$HOME/bin" ~/.bashrc 2>/dev/null && ! grep -q "export PATH=.*~/bin" ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        echo "✅ 已添加到 PATH"
    fi
    
    INSTALL_PATH="$HOME/bin/hycrypt"
else
    # 尝试系统目录（需要管理员权限）
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$PROJECT_DIR/hycrypt" /usr/local/bin/hycrypt
        echo "✅ 已安装到 /usr/local/bin/hycrypt"
        INSTALL_PATH="/usr/local/bin/hycrypt"
    else
        echo "❌ 无法创建符号链接，请检查权限"
        echo "尝试运行: sudo $0"
        exit 1
    fi
fi

# 测试安装
echo "🧪 测试安装..."
if command -v hycrypt &> /dev/null; then
    echo "✅ 安装成功！"
    echo ""
    echo "🎉 现在您可以在任何目录运行 hycrypt 命令："
    echo "   hycrypt --help"
    echo "   hycrypt -e file.txt -p password"
    echo "   hycrypt -d file.txt.enc -p password"
    echo ""
    hycrypt --help | head -5
else
    echo "❌ 安装失败，请检查 PATH 配置"
    echo "当前 PATH: $PATH"
    exit 1
fi

echo ""
echo "🎉 配置完成！"
echo "💡 如果新终端无法识别命令，请运行: source ~/.bashrc"