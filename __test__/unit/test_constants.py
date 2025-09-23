#!/usr/bin/env python3
"""
常量模块单元测试
"""

import unittest
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from constants import (
    ENCRYPTED_FILE_EXTENSION, RESTORED_FILE_SUFFIX,
    DIRECTORY_ARCHIVE_FORMAT, DIRECTORY_ARCHIVE_SUFFIX,
    DIRECTORY_ARCHIVE_DATE_FORMAT, DIRECTORY_ARCHIVE_NAME_PATTERN,
    DEMO_DIR, ARGON2_ITERATIONS, ARGON2_MEMORY_COST,
    ARGON2_LANES, ARGON2_SALT_LENGTH, ARGON2_KEY_LENGTH,
    AES_IV_LENGTH, AES_KEY_LENGTH, AES_BLOCK_SIZE,
    PASSWORD_HASHER_TIME_COST, PASSWORD_HASHER_MEMORY_COST,
    PASSWORD_HASHER_PARALLELISM
)


class TestConstants(unittest.TestCase):
    """测试常量定义"""
    
    def test_file_extension_constants(self):
        """测试文件扩展名常量"""
        self.assertEqual(ENCRYPTED_FILE_EXTENSION, ".enc")
        self.assertEqual(RESTORED_FILE_SUFFIX, ".restored")
        self.assertEqual(DIRECTORY_ARCHIVE_FORMAT, "zip")
        self.assertEqual(DIRECTORY_ARCHIVE_SUFFIX, ".zip")
        self.assertEqual(DEMO_DIR, "__demo__")
    
    def test_argon2_constants(self):
        """测试 Argon2 常量"""
        self.assertIsInstance(ARGON2_ITERATIONS, int)
        self.assertIsInstance(ARGON2_MEMORY_COST, int)
        self.assertIsInstance(ARGON2_LANES, int)
        self.assertIsInstance(ARGON2_SALT_LENGTH, int)
        self.assertIsInstance(ARGON2_KEY_LENGTH, int)
        
        # 验证合理的数值范围
        self.assertGreater(ARGON2_ITERATIONS, 0)
        self.assertGreater(ARGON2_MEMORY_COST, 0)
        self.assertGreater(ARGON2_LANES, 0)
        self.assertGreater(ARGON2_SALT_LENGTH, 0)
        self.assertGreater(ARGON2_KEY_LENGTH, 0)
    
    def test_aes_constants(self):
        """测试 AES 常量"""
        self.assertIsInstance(AES_IV_LENGTH, int)
        self.assertIsInstance(AES_KEY_LENGTH, int)
        self.assertIsInstance(AES_BLOCK_SIZE, int)
        
        # 验证 AES 标准长度
        self.assertEqual(AES_IV_LENGTH, 16)  # 128位
        self.assertEqual(AES_KEY_LENGTH, 32)  # 256位
        self.assertEqual(AES_BLOCK_SIZE, 16)  # 128位
    
    def test_password_hasher_constants(self):
        """测试密码哈希器常量"""
        self.assertIsInstance(PASSWORD_HASHER_TIME_COST, int)
        self.assertIsInstance(PASSWORD_HASHER_MEMORY_COST, int)
        self.assertIsInstance(PASSWORD_HASHER_PARALLELISM, int)
        
        # 验证合理的数值范围
        self.assertGreater(PASSWORD_HASHER_TIME_COST, 0)
        self.assertGreater(PASSWORD_HASHER_MEMORY_COST, 0)
        self.assertGreater(PASSWORD_HASHER_PARALLELISM, 0)
    
    def test_directory_archive_pattern(self):
        """测试目录归档命名模式"""
        self.assertIsInstance(DIRECTORY_ARCHIVE_NAME_PATTERN, str)
        self.assertIn("{date}", DIRECTORY_ARCHIVE_NAME_PATTERN)
        self.assertIn("{dirname}", DIRECTORY_ARCHIVE_NAME_PATTERN)
        self.assertIn("{suffix}", DIRECTORY_ARCHIVE_NAME_PATTERN)
        
        # 验证日期格式
        self.assertIsInstance(DIRECTORY_ARCHIVE_DATE_FORMAT, str)
        self.assertEqual(DIRECTORY_ARCHIVE_DATE_FORMAT, "%Y%m%d")


if __name__ == '__main__':
    unittest.main()