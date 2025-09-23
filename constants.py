#!/usr/bin/env python3
"""
常量定义模块
定义程序中使用的所有常量
"""

# 文件扩展名常量
ENCRYPTED_FILE_EXTENSION = ".hycrypt"  # 加密文件后缀
RESTORED_FILE_SUFFIX = ".restored"  # 非标准加密文件解密后的后缀

# 目录压缩相关常量
DIRECTORY_ARCHIVE_FORMAT = "zip"  # 目录压缩格式
DIRECTORY_ARCHIVE_SUFFIX = ".zip"  # 压缩文件后缀
DIRECTORY_ARCHIVE_DATE_FORMAT = "%Y%m%d"  # 日期格式：年月日
DIRECTORY_ARCHIVE_NAME_PATTERN = "{date}-{dirname}{suffix}"  # 压缩文件命名格式

# 演示目录
DEMO_DIR = "__demo__"  # 演示目录

# Argon2id 参数配置 - 高强度安全设置 (2024标准)
ARGON2_ITERATIONS = 5  # 增加迭代次数提高安全性
ARGON2_MEMORY_COST = 262144  # 256MB - 符合OWASP高安全推荐
ARGON2_LANES = 6  # 增加并行度利用多核CPU
ARGON2_SALT_LENGTH = 16  # 128位
ARGON2_KEY_LENGTH = 32  # 256位

# AES 加密参数
AES_IV_LENGTH = 16  # 128位
AES_KEY_LENGTH = 32  # 256位
AES_BLOCK_SIZE = 16  # 128位

# 密码哈希器参数 - 同步提升强度
PASSWORD_HASHER_TIME_COST = 12  # 增加时间成本
PASSWORD_HASHER_MEMORY_COST = 262144  # 256MB - 与Argon2id保持一致
PASSWORD_HASHER_PARALLELISM = 6  # 与Argon2id并行度匹配