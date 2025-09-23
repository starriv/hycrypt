# 🔐 Hycrypt File Encryption/Decryption Tool

A secure file encryption/decryption tool based on modern cryptographic standards, featuring AES-256-CBC encryption algorithm and Argon2id key derivation function. Supports file and directory encryption with password confirmation mechanism to ensure encryption security.

## 🚀 Quick Start

### 标准运行方式
```bash
# 安装依赖
pip install -r requirements.txt

# 运行程序
python3 main.py

# 查看帮助
python3 main.py --help
```

### 系统 PATH 配置（推荐）
配置后可在任意目录运行：

```bash
# 一键配置脚本（推荐）
bash scripts/setup_path.sh

# 或者手动配置：
# 需要管理员权限
sudo ln -sf "$(pwd)/hycrypt" /usr/local/bin/hycrypt

# 或者用户目录（无需管理员权限）
mkdir -p ~/bin
ln -sf "$(pwd)/hycrypt" ~/bin/hycrypt

# 现在可以在任意目录运行
hycrypt --help
```

📖 [详细安装指南](docs/INSTALL.md) | 📋 [PATH 配置指南](docs/PATH_SETUP.md)

## ✨ Key Features

- **Dual Operation Modes**: Supports both interactive interface and command-line parameters
- **Secure Encryption**: Uses industry-standard AES-256-CBC encryption algorithm
- **Strong Key Derivation**: Utilizes Argon2id (winner of 2015 Password Hashing Competition)
- **Smart File Naming**: Automatically restores original filename after decryption, no extra suffixes
- **Directory Encryption**: Supports directory compression encryption with automatic multi-level subdirectory handling
- **Password Confirmation**: Enforces double confirmation during encryption to prevent password input errors
- **Algorithm Display**: Real-time display of current encryption algorithm information
- **Custom Output**: Supports specifying encryption/decryption output filenames
- **File Integrity**: Automatically handles file size and format

## 🔬 Program Principles

### Encryption Process

1. **Key Derivation**: Derives 256-bit encryption key from user password using Argon2id
2. **Random Parameter Generation**: Generates 128-bit random salt and initialization vector (IV)
3. **Preprocessing Check**: If it's a directory, compresses it to ZIP format first
4. **AES Encryption**: Encrypts file content using AES-256-CBC mode
5. **Data Assembly**: Combines salt, IV, and ciphertext into encrypted file
6. **Post-processing**: Cleans up temporary compression files (for directory encryption)

### Decryption Process

1. **Parameter Extraction**: Extracts salt, IV, and ciphertext from encrypted file
2. **Key Reconstruction**: Re-derives decryption key using same Argon2id parameters
3. **AES Decryption**: Decrypts ciphertext using AES-256-CBC mode
4. **Data Recovery**: Removes padding and restores original file content
5. **Post-processing**: If it's a compressed file, automatically decompresses and restores directory structure

### Security Design

- **Forward Secrecy**: Uses random salt and IV for each encryption
- **Password Verification**: Naturally verifies password correctness through decryption results
- **Password Confirmation**: Enforces double confirmation during encryption to prevent password input errors
- **Data Integrity**: PKCS#7 padding ensures data integrity
- **No Password Storage**: System does not store user passwords, fully decentralized
- **Algorithm Transparency**: Real-time display of encryption algorithm information used

## 🛡️ Algorithm Advantages

### AES-256-CBC Encryption

- **Key Length**: 256 bits, providing military-grade security strength
- **Encryption Mode**: CBC (Cipher Block Chaining), enhanced security
- **Block Size**: 128 bits, compliant with industrial standards
- **Padding Scheme**: PKCS#7, ensures data integrity

### Argon2id Key Derivation

- **Memory Consumption**: 64MB, resistant to hardware attacks
- **Time Cost**: 10 iterations, balancing security and performance
- **Parallelism**: 4 threads, fully utilizing multi-core processors
- **Salt**: 128-bit random number, preventing rainbow table attacks

## 🚀 Quick Start

### Interactive Interface

```bash
python encrypt.py
```

### Command Line Encryption

```bash
# Basic file encryption
python encrypt.py -e file.txt -p password

# Specify output filename
python encrypt.py -e file.txt -p password -o custom_name.enc

# Directory encryption (automatic compression)
python encrypt.py -e directory_path -p password
```

### Command Line Decryption

```bash
# Basic file decryption
python encrypt.py -d file.txt.enc -p password

# Specify output filename
python encrypt.py -d file.txt.enc -p password -o restored_file.txt

# Directory decryption (automatic decompression)
python encrypt.py -d 20250923-directory.zip.enc -p password
```

## 🔧 Technical Features

| Feature           | Description               |
| ---------------- | ------------------------- |
| **Encryption Algorithm**   | AES-256-CBC        |
| **Key Derivation**   | Argon2id           |
| **Key Length**   | 256 bits             |
| **Salt Length**   | 128 bits             |
| **IV Length**    | 128 bits             |
| **File Format**   | Supports any file type     |
| **Directory Encryption**   | Automatically compresses multi-level directories |
| **Password Confirmation**  | Enforces double confirmation mechanism |
| **Algorithm Display**  | Real-time display of encryption algorithm |
| **Large File Handling** | Supports large file streaming processing |

## 🧪 Testing and Validation

Run comprehensive test suite:

```bash
python run_tests.py
```

Tests include:

- ✅ Basic encryption/decryption functionality
- ✅ Command-line interface testing
- ✅ Error handling mechanisms
- ✅ Parameter validation
- ✅ Incorrect password handling
- ✅ Large file processing
- ✅ Interactive interface testing
- ✅ Directory encryption/decryption functionality (multi-level)
- ✅ Password confirmation mechanism
- ✅ Algorithm information display

## 📁 File Structure

```
encrypt.py              # Main program file
test_integrated.py      # Comprehensive test suite
run_tests.py           # Test runner
__demo__/              # Demo directory (test only)
.claude/FILING_RULES.md # File management rules
README.md              # This document
```

## 📋 File Management Rules

### Working Directory Management

- **User Files**: Encrypted/decrypted files remain in original directory location
- **Test Files**: All test files are stored in `__demo__` directory
- **Directory Encryption**: Compressed files are generated in same-level location as original directory
- **Naming Format**: Directory encryption uses `YYYYMMDD-directory_name.zip.enc` format

### Usage Guidelines

- User encrypted files are directly output to source file directory
- Test and demo files are uniformly placed in `__demo__` directory
- Temporary compressed files are automatically cleaned up to maintain directory cleanliness

## 🔒 Security Notes

1. **Password Strength**: Recommended password length of at least 6 characters
2. **Password Confirmation**: Enforces double confirmation during encryption to prevent password input errors
3. **File Backup**: Please backup important files before encryption
4. **Password Management**: Please keep encryption passwords safe; forgotten passwords cannot recover files
5. **Encryption Verification**: Please verify file integrity after encryption
6. **Algorithm Transparency**: Real-time display of encryption algorithms used ensures security visibility

## 📋 Usage Recommendations

- **Personal File Protection**: Protect sensitive documents, photos and other personal privacy
- **Directory Encryption**: Batch encrypt entire folders including all subdirectories
- **Data Transfer**: Secure transfer of important files
- **Backup Encryption**: Encrypt backup files for protection
- **Work Documents**: Protect business secrets and work files
- **Project Archiving**: Encrypt entire project directories for secure storage

## 🎯 Algorithm Standards

The encryption scheme implemented in this tool complies with the following international standards:

- **AES**: FIPS PUB 197 standard
- **PBKDF2**: RFC 2898 standard
- **Argon2**: PHC (Password Hashing Competition) standard