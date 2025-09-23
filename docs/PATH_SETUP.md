# hycrypt-py 系统 PATH 配置指南 | System PATH Configuration Guide

## 中文配置指南

### 📋 概述

将 hycrypt-py 添加到系统 PATH 后，您可以在任何目录直接运行 `hycrypt` 命令，无需进入项目目录。

### ⚡ 快速配置

#### 方法 1：创建符号链接（推荐）

```bash
# 1. 找到系统的可执行文件目录
# Linux/macOS:
sudo ln -sf "$(pwd)/hycrypt" /usr/local/bin/hycrypt

# 或者用户目录（不需要sudo）:
mkdir -p ~/bin
ln -sf "$(pwd)/hycrypt" ~/bin/hycrypt
# 确保 ~/bin 在PATH中（通常已包含）
```

#### 方法 2：添加到 PATH 环境变量

**临时添加（当前会话有效）：**

```bash
export PATH="$PATH:$(pwd)"
hycrypt --help
```

**永久添加（推荐）：**

**Linux/macOS:**

```bash
# 编辑 shell 配置文件
# 对于 Bash 用户：
echo 'export PATH="$PATH:'"$(pwd)"'"' >> ~/.bashrc
source ~/.bashrc

# 对于 Zsh 用户（macOS 默认）：
echo 'export PATH="$PATH:'"$(pwd)"'"' >> ~/.zshrc
source ~/.zshrc

# 对于其他 shell，编辑相应的配置文件（~/.profile, ~/.zprofile 等）
```

**Windows:**

```powershell
# 临时添加
$env:PATH += ";$(pwd)"

# 永久添加（需要管理员权限）
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$(pwd)", [EnvironmentVariableTarget]::Machine)
```

#### 方法 3：安装到 Python Scripts 目录

```bash
# 创建 setup.py 文件（见下文）
python3 setup.py install --user
# 或者
pip install -e .
```

### 🔧 验证配置

```bash
# 测试是否可以在任意目录运行
hycrypt --help

# 应该显示程序帮助信息
# 如果成功，说明 PATH 配置正确
```

### 📦 创建 setup.py（高级方法）

如果需要更专业的安装方式，可以创建 setup.py：

```python
from setuptools import setup, find_packages

setup(
    name="hycrypt-py",
    version="1.0.0",
    description="Secure file encryption/decryption tool",
    author="Your Name",
    packages=find_packages(),
    entry_points={
        'console_scripts': [
            'hycrypt=hycrypt:main',
        ],
    },
    install_requires=[
        'cryptography>=3.4.8',
    ],
    python_requires='>=3.7',
)
```

然后安装：

```bash
pip install -e .
```

### 🔧 Shell 特定配置

#### 识别您的 Shell
```bash
echo $SHELL  # 显示当前 shell
```

#### macOS 用户（Zsh）
macOS 10.15+ 默认使用 Zsh，需要配置 `~/.zshrc`：
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### Linux 用户（Bash）
大多数 Linux 系统默认使用 Bash，配置 `~/.bashrc`：
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 新终端会话测试
打开新的终端窗口，运行：
```bash
hycrypt --help  # 应该显示帮助信息
```

### 🔧 常见问题

#### 1. 权限问题

```bash
# 使用用户目录（推荐）
mkdir -p ~/bin
ln -sf "$(pwd)/hycrypt" ~/bin/hycrypt

# 确保 ~/bin 在 PATH 中
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. 路径中包含空格

```bash
# 使用引号处理路径
ln -sf "$(pwd)/hycrypt" "/usr/local/bin/hycrypt"
```

#### 3. 多个 Python 版本冲突

```bash
# 指定 Python 版本
python3 -m pip install -e .
# 或者
python3.10 -m pip install -e .
```

#### 4. Shell 类型不匹配

如果配置后命令仍无法识别，可能是 Shell 配置文件不匹配：

```bash
# 检查当前 shell
echo $SHELL

# 如果返回 /bin/zsh，确保配置 ~/.zshrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 如果返回 /bin/bash，确保配置 ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 打开新终端窗口测试
hycrypt --help
```

### 🧪 测试配置

```bash
# 创建测试脚本
cat > test_hycrypt.sh << 'EOF'
#!/bin/bash
echo "测试 hycrypt 命令..."
hycrypt --help
echo "测试完成"
EOF

chmod +x test_hycrypt.sh
./test_hycrypt.sh
```

### 🔧 卸载配置

```bash
# 删除符号链接
sudo rm /usr/local/bin/hycrypt
# 或者
rm ~/bin/hycrypt

# 从 PATH 中移除（编辑 ~/.bashrc 删除相关行）
```

---

## English Configuration Guide

### 📋 Overview

After adding hycrypt-py to system PATH, you can run the `hycrypt` command from any directory without navigating to the project folder.

### ⚡ Quick Configuration

#### Method 1: Create Symbolic Link (Recommended)

```bash
# 1. Find system executable directory
# Linux/macOS:
sudo ln -sf "$(pwd)/hycrypt" /usr/local/bin/hycrypt

# Or user directory (no sudo needed):
mkdir -p ~/bin
ln -sf "$(pwd)/hycrypt" ~/bin/hycrypt
# Ensure ~/bin is in PATH (usually included)
```

#### Method 2: Add to PATH Environment Variable

**Temporary (current session only):**

```bash
export PATH="$PATH:$(pwd)"
hycrypt --help
```

**Permanent (recommended):**

**Linux/macOS:**

```bash
# Edit shell configuration file
# For Bash users:
echo 'export PATH="$PATH:'"$(pwd)"'"' >> ~/.bashrc
source ~/.bashrc

# For Zsh users (macOS default):
echo 'export PATH="$PATH:'"$(pwd)"'"' >> ~/.zshrc
source ~/.zshrc

# For other shells, edit respective config files (~/.profile, ~/.zprofile, etc.)
```

**Windows:**

```powershell
# Temporary
$env:PATH += ";$(pwd)"

# Permanent (requires admin privileges)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$(pwd)", [EnvironmentVariableTarget]::Machine)
```

#### Method 3: Install to Python Scripts Directory

```bash
# Create setup.py file (see below)
python3 setup.py install --user
# or
pip install -e .
```

### 🔧 Verification

```bash
# Test if command works from any directory
hycrypt --help

# Should display program help information
# If successful, PATH configuration is correct
```

### 📦 Create setup.py (Advanced Method)

For more professional installation, create setup.py:

```python
from setuptools import setup, find_packages

setup(
    name="hycrypt-py",
    version="1.0.0",
    description="Secure file encryption/decryption tool",
    author="Your Name",
    packages=find_packages(),
    entry_points={
        'console_scripts': [
            'hycrypt=hycrypt:main',
        ],
    },
    install_requires=[
        'cryptography>=3.4.8',
    ],
    python_requires='>=3.7',
)
```

Then install:

```bash
pip install -e .
```

### 🔧 Shell-specific Configuration

#### Identify Your Shell
```bash
echo $SHELL  # Show current shell
```

#### macOS Users (Zsh)
macOS 10.15+ uses Zsh by default, configure `~/.zshrc`:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### Linux Users (Bash)
Most Linux systems use Bash by default, configure `~/.bashrc`:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### New Terminal Session Test
Open a new terminal window and run:
```bash
hycrypt --help  # Should show help information
```

### 🔧 Common Issues

#### 1. Permission Issues

```bash
# Use user directory (recommended)
mkdir -p ~/bin
ln -sf "$(pwd)/hycrypt" ~/bin/hycrypt

# Ensure ~/bin is in PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. Paths with Spaces

```bash
# Use quotes for paths with spaces
ln -sf "$(pwd)/hycrypt" "/usr/local/bin/hycrypt"
```

#### 3. Multiple Python Version Conflicts

```bash
# Specify Python version
python3 -m pip install -e .
# or
python3.10 -m pip install -e .
```

#### 4. Shell Type Mismatch

If the command is still not recognized after configuration, it might be a shell configuration mismatch:

```bash
# Check current shell
echo $SHELL

# If it returns /bin/zsh, configure ~/.zshrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# If it returns /bin/bash, configure ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Open new terminal window to test
hycrypt --help
```

### 🧪 Test Configuration

```bash
# Create test script
cat > test_hycrypt.sh << 'EOF'
#!/bin/bash
echo "Testing hycrypt command..."
hycrypt --help
echo "Test completed"
EOF

chmod +x test_hycrypt.sh
./test_hycrypt.sh
```

### 🔧 Uninstall Configuration

```bash
# Remove symbolic link
sudo rm /usr/local/bin/hycrypt
# or
rm ~/bin/hycrypt

# Remove from PATH (edit ~/.bashrc to delete related lines)
```

---

## 🚀 一键配置脚本 | One-Click Setup Script

### 自动配置脚本

保存为 `scripts/setup_path.sh`：

```bash
#!/bin/bash
# hycrypt-py PATH 配置脚本

echo "🚀 配置 hycrypt-py 系统 PATH..."

# 获取当前目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 创建符号链接
echo "创建符号链接..."
if [ -w "/usr/local/bin" ]; then
    sudo ln -sf "$SCRIPT_DIR/hycrypt" /usr/local/bin/hycrypt
    echo "✅ 已安装到 /usr/local/bin/hycrypt"
else
    mkdir -p ~/bin
    ln -sf "$SCRIPT_DIR/hycrypt" ~/bin/hycrypt
    echo "✅ 已安装到 ~/bin/hycrypt"

    # 添加到 PATH
    if ! grep -q "export PATH=.*~/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        echo "✅ 已添加到 PATH"
    fi
fi

# 测试安装
echo "测试安装..."
if command -v hycrypt &> /dev/null; then
    echo "✅ 安装成功！"
    hycrypt --help | head -5
else
    echo "❌ 安装失败，请检查 PATH 配置"
fi

echo "🎉 配置完成！"
echo "现在您可以在任何目录运行: hycrypt --help"
```

使用方法：

```bash
chmod +x scripts/setup_path.sh
./scripts/setup_path.sh
```

---

## 📋 总结 | Summary

### 推荐方案（按优先级）：

1. **符号链接到 ~/bin**（用户目录，无需管理员权限）
2. **符号链接到 /usr/local/bin**（系统范围，需要管理员权限）
3. **pip 安装**（最专业，需要 setup.py）
4. **修改 PATH**（简单但可能影响其他程序）

### 验证命令：

```bash
hycrypt --help          # 应该显示帮助信息
which hycrypt           # 显示 hycrypt 位置
type hycrypt            # 显示命令类型
```

### 卸载方法：

```bash
# 根据安装方式选择卸载方法
sudo rm /usr/local/bin/hycrypt  # 如果是系统安装
rm ~/bin/hycrypt                # 如果是用户安装
pip uninstall hycrypt-py        # 如果是 pip 安装
```

现在您可以在任何目录直接使用 `hycrypt` 命令了！

---

_最后更新：2025 年_ | _Last updated: 2025_”，
