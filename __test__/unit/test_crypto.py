#!/usr/bin/env python3
"""
加密模块单元测试
"""

import unittest
import sys
import os
import tempfile

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from crypto import CryptoManager
from constants import ARGON2_SALT_LENGTH, AES_IV_LENGTH


class TestCryptoManager(unittest.TestCase):
    """测试加密管理器"""
    
    def setUp(self):
        """测试前的设置"""
        self.crypto_manager = CryptoManager()
        self.test_password = "test_password_123"
        self.test_data = b"This is test data for encryption"
    
    def test_generate_random_bytes(self):
        """测试随机字节生成"""
        # 测试不同长度
        for length in [16, 32, 64]:
            random_bytes = self.crypto_manager.generate_random_bytes(length)
            self.assertEqual(len(random_bytes), length)
            self.assertIsInstance(random_bytes, bytes)
            
            # 验证随机性（基本检查）
            random_bytes2 = self.crypto_manager.generate_random_bytes(length)
            self.assertNotEqual(random_bytes, random_bytes2)
    
    def test_derive_key(self):
        """测试密钥派生"""
        # 生成盐值
        salt = self.crypto_manager.generate_random_bytes(ARGON2_SALT_LENGTH)
        
        # 派生密钥
        key1 = self.crypto_manager.derive_key(self.test_password, salt)
        key2 = self.crypto_manager.derive_key(self.test_password, salt)
        
        # 相同输入应该产生相同结果
        self.assertEqual(key1, key2)
        self.assertIsInstance(key1, bytes)
        self.assertGreater(len(key1), 0)
        
        # 不同盐值应该产生不同结果
        salt2 = self.crypto_manager.generate_random_bytes(ARGON2_SALT_LENGTH)
        key3 = self.crypto_manager.derive_key(self.test_password, salt2)
        self.assertNotEqual(key1, key3)
        
        # 不同密码应该产生不同结果
        key4 = self.crypto_manager.derive_key("different_password", salt)
        self.assertNotEqual(key1, key4)
    
    def test_encrypt_decrypt_data(self):
        """测试数据加密解密"""
        # 加密数据
        salt, iv, ciphertext = self.crypto_manager.encrypt_data(self.test_data, self.test_password)
        
        # 验证返回的数据格式
        self.assertIsInstance(salt, bytes)
        self.assertIsInstance(iv, bytes)
        self.assertIsInstance(ciphertext, bytes)
        self.assertEqual(len(salt), ARGON2_SALT_LENGTH)
        self.assertEqual(len(iv), AES_IV_LENGTH)
        self.assertGreater(len(ciphertext), 0)
        
        # 验证密文与原文不同
        self.assertNotEqual(ciphertext, self.test_data)
        
        # 解密数据
        decrypted_data = self.crypto_manager.decrypt_data(salt, iv, ciphertext, self.test_password)
        
        # 验证解密结果
        self.assertEqual(decrypted_data, self.test_data)
        self.assertIsInstance(decrypted_data, bytes)
    
    def test_encrypt_decrypt_with_wrong_password(self):
        """测试使用错误密码解密"""
        # 加密数据
        salt, iv, ciphertext = self.crypto_manager.encrypt_data(self.test_data, self.test_password)
        
        # 使用错误密码解密应该失败
        with self.assertRaises(Exception):
            self.crypto_manager.decrypt_data(salt, iv, ciphertext, "wrong_password")
    
    def test_encrypt_decrypt_file_data(self):
        """测试文件数据加密解密"""
        # 创建临时文件
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_file.write(self.test_data)
            temp_file_path = temp_file.name
        
        try:
            # 加密文件
            encrypted_data = self.crypto_manager.encrypt_file_data(temp_file_path, self.test_password)
            
            # 验证加密数据
            self.assertIsInstance(encrypted_data, bytes)
            self.assertGreater(len(encrypted_data), len(self.test_data))  # 加密数据应该包含元数据
            
            # 解密数据
            decrypted_data = self.crypto_manager.decrypt_file_data(encrypted_data, self.test_password)
            
            # 验证解密结果
            self.assertEqual(decrypted_data, self.test_data)
            
        finally:
            # 清理临时文件
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)
    
    def test_encrypt_decrypt_empty_data(self):
        """测试空数据加密解密"""
        empty_data = b""
        
        # 加密空数据
        salt, iv, ciphertext = self.crypto_manager.encrypt_data(empty_data, self.test_password)
        
        # 验证加密结果
        self.assertIsInstance(salt, bytes)
        self.assertIsInstance(iv, bytes)
        self.assertIsInstance(ciphertext, bytes)
        
        # 解密空数据
        decrypted_data = self.crypto_manager.decrypt_data(salt, iv, ciphertext, self.test_password)
        self.assertEqual(decrypted_data, empty_data)
    
    def test_encrypt_decrypt_large_data(self):
        """测试大数据加密解密"""
        # 创建 1MB 的测试数据
        large_data = os.urandom(1024 * 1024)
        
        # 加密大数据
        salt, iv, ciphertext = self.crypto_manager.encrypt_data(large_data, self.test_password)
        
        # 验证加密结果
        self.assertIsInstance(salt, bytes)
        self.assertIsInstance(iv, bytes)
        self.assertIsInstance(ciphertext, bytes)
        self.assertGreater(len(ciphertext), 0)
        
        # 解密大数据
        decrypted_data = self.crypto_manager.decrypt_data(salt, iv, ciphertext, self.test_password)
        
        # 验证解密结果
        self.assertEqual(decrypted_data, large_data)
        self.assertEqual(len(decrypted_data), len(large_data))


if __name__ == '__main__':
    unittest.main()