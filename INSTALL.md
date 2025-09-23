# hycrypt-py 安装指南 | Installation Guide

---

## 中文安装指南

### 📋 系统要求

- Python 3.7 或更高版本
- 支持的操作系统：Linux、macOS、Windows

### ⚡ 快速安装

```bash
# 1. 克隆项目
git clone https://github.com/your-username/hycrypt-py.git
cd hycrypt-py

# 2. 安装依赖
pip install -r requirements.txt

# 3. 验证安装
python3 main.py --help
```

### 🔧 详细安装步骤

#### 方法 1：使用 pip 安装依赖（推荐）

```bash
# 创建虚拟环境（可选但推荐）
python3 -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate     # Windows

# 安装依赖
pip install -r requirements.txt

# 运行程序
python3 main.py
```

#### 方法 2：手动安装依赖

如果只使用核心功能，只需要安装 cryptography：

```bash
pip install cryptography
```

### 📦 依赖说明

#### 核心依赖（requirements.txt）

| 包名         | 版本    | 用途                                      |
| ------------ | ------- | ----------------------------------------- |
| cryptography | >=3.4.8 | 提供 AES-256-CBC 加密和 Argon2id 密钥派生 |

#### 标准库依赖（无需安装）

- `os` - 文件系统操作
- `sys` - 系统相关功能
- `json` - JSON 处理
- `getpass` - 密码输入
- `argparse` - 命令行参数解析
- `zipfile` - ZIP 压缩/解压
- `datetime` - 日期时间处理
- `re` - 正则表达式
- `locale` - 系统区域设置检测

### 🧪 验证安装

运行以下命令验证安装是否成功：

```bash
# 检查Python版本
python3 --version

# 检查依赖
python3 -c "
import sys
print('Python版本:', sys.version)
try:
    import cryptography
    print('cryptography版本:', cryptography.__version__)
    print('✅ 安装成功')
except ImportError as e:
    print('❌ 安装失败:', e)
"

# 运行程序帮助
python3 main.py --help

# 测试多语言支持
python3 main.py --help --lang en
python3 main.py --help --lang zh
```

### 🔧 常见问题

#### 1. pip 安装失败

```bash
# 升级pip
python3 -m pip install --upgrade pip

# 重新安装
pip install cryptography
```

#### 2. 权限问题

```bash
# 使用用户目录安装
pip install --user cryptography
```

#### 3. 网络问题

```bash
# 使用国内镜像源
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

---

## Installation Guide

### 📋 System Requirements

- Python 3.7 or higher
- Supported operating systems: Linux, macOS, Windows

### ⚡ Quick Install

```bash
# 1. Clone the project
git clone https://github.com/your-username/hycrypt-py.git
cd hycrypt-py

# 2. Install dependencies
pip install -r requirements.txt

# 3. Verify installation
python3 main.py --help
```

### 🔧 Detailed Installation Steps

#### Method 1: Install dependencies with pip (recommended)

```bash
# Create virtual environment (optional but recommended)
python3 -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Run the program
python3 main.py
```

#### Method 2: Manual dependency installation

If you only need core functionality, just install cryptography:

```bash
pip install cryptography
```

### 📦 Dependency Description

#### Core Dependencies (requirements.txt)

| Package      | Version | Purpose                                                     |
| ------------ | ------- | ----------------------------------------------------------- |
| cryptography | >=3.4.8 | Provides AES-256-CBC encryption and Argon2id key derivation |

#### Standard Library Dependencies (built-in, no installation needed)

- `os` - File system operations
- `sys` - System related functions
- `json` - JSON processing
- `getpass` - Password input
- `argparse` - Command line argument parsing
- `zipfile` - ZIP compression/decompression
- `datetime` - Date and time processing
- `re` - Regular expressions
- `locale` - System locale detection

### 🧪 Installation Verification

Run the following commands to verify successful installation:

```bash
# Check Python version
python3 --version

# Check dependencies
python3 -c "
import sys
print('Python version:', sys.version)
try:
    import cryptography
    print('cryptography version:', cryptography.__version__)
    print('✅ Installation successful')
except ImportError as e:
    print('❌ Installation failed:', e)
"

# Run program help
python3 main.py --help

# Test multilingual support
python3 main.py --help --lang en
python3 main.py --help --lang zh
```

### 🔧 Common Issues

#### 1. pip installation fails

```bash
# Upgrade pip
python3 -m pip install --upgrade pip

# Reinstall
pip install cryptography
```

#### 2. Permission issues

```bash
# Use user directory installation
pip install --user cryptography
```

#### 3. Network issues

```bash
# Use domestic mirror source (China)
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

---

## 🌍 Platform Specific Instructions

### macOS

```bash
# If using Homebrew Python
brew install python@3.10
pip3 install -r requirements.txt
```

### Linux (Ubuntu/Debian)

```bash
# Ensure Python and pip are installed
sudo apt update
sudo apt install python3 python3-pip
pip3 install -r requirements.txt
```

### Windows

```bash
# Use Python installer to ensure pip is available
python -m pip install -r requirements.txt
```

---

## 🔄 Update Dependencies

```bash
# Update all dependencies
pip install --upgrade -r requirements.txt

# Update specific package
pip install --upgrade cryptography
```

---

## 🗑️ Uninstall

```bash
# Uninstall dependencies
pip uninstall cryptography

# Or delete entire virtual environment
deactivate
rm -rf venv/
```

---

## 📞 Getting Help

If you encounter installation issues:

1. Check if Python version meets requirements
2. Ensure network connection is normal
3. Look at error messages, usually dependency conflicts or network issues
4. Consider using virtual environment to isolate dependencies

---

_最后更新：2025 年_ | _Last updated: 2025_
