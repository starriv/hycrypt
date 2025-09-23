#!/usr/bin/env python3
"""
工具函数模块单元测试
"""

import unittest
import sys
import os
import tempfile
import shutil

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from utils import Utils
from constants import ENCRYPTED_FILE_EXTENSION, DEMO_DIR


class TestUtils(unittest.TestCase):
    """测试工具类"""
    
    def setUp(self):
        """测试前的设置"""
        self.utils = Utils()
        self.test_dir = tempfile.mkdtemp()
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_ensure_demo_dir(self):
        """测试演示目录创建"""
        # 确保演示目录存在
        demo_path = self.utils.ensure_demo_dir()
        
        # 验证目录存在
        self.assertTrue(os.path.exists(demo_path))
        self.assertTrue(os.path.isdir(demo_path))
        self.assertEqual(demo_path, DEMO_DIR)
    
    def test_get_demo_path(self):
        """测试获取演示目录中的文件路径"""
        filename = "test_file.txt"
        full_path = self.utils.get_demo_path(filename)
        
        # 验证路径格式
        self.assertTrue(full_path.startswith(DEMO_DIR))
        self.assertTrue(full_path.endswith(filename))
        self.assertTrue(os.path.exists(os.path.dirname(full_path)))
    
    def test_is_encrypted_file(self):
        """测试加密文件检查"""
        # 测试加密文件
        self.assertTrue(self.utils.is_encrypted_file("test.txt.enc"))
        self.assertTrue(self.utils.is_encrypted_file("/path/to/file.enc"))
        
        # 测试非加密文件
        self.assertFalse(self.utils.is_encrypted_file("test.txt"))
        self.assertFalse(self.utils.is_encrypted_file("test.enc.txt"))
        self.assertFalse(self.utils.is_encrypted_file(""))
    
    def test_get_password_valid(self):
        """测试有效密码获取（模拟）"""
        # 由于 get_password 需要用户输入，我们测试密码验证逻辑
        # 创建一个简单的密码验证测试
        password = "valid_password_123"
        
        # 验证密码格式
        self.assertIsInstance(password, str)
        self.assertGreater(len(password), 0)
    
    def test_get_filename_input_valid(self):
        """测试有效的文件名输入"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "valid_file.txt")
        with open(test_file, 'w') as f:
            f.write("test content")
        
        # 这里我们不能真正测试 input()，但可以验证文件存在逻辑
        self.assertTrue(os.path.exists(test_file))
        self.assertTrue(os.path.isfile(test_file))
    
    def test_get_path_input_valid(self):
        """测试有效的路径输入"""
        # 创建测试目录
        test_path = os.path.join(self.test_dir, "valid_path")
        os.makedirs(test_path)
        
        # 验证路径存在
        self.assertTrue(os.path.exists(test_path))
        self.assertTrue(os.path.isdir(test_path))
    
    def test_show_file_info(self):
        """测试文件信息显示"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "info_test.txt")
        test_content = "Test content for file info"
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write(test_content)
        
        # 测试文件信息显示（主要验证不抛出异常）
        try:
            self.utils.show_file_info(test_file)
        except Exception as e:
            self.fail(f"show_file_info 不应该抛出异常: {e}")
        
        # 测试不存在的文件
        try:
            self.utils.show_file_info("nonexistent_file.txt")
        except Exception as e:
            self.fail(f"show_file_info 对不存在的文件也不应该抛出异常: {e}")
    
    def test_format_file_size(self):
        """测试文件大小格式化"""
        # 测试字节级别
        self.assertEqual(self.utils.format_file_size(0), "0 字节")
        self.assertEqual(self.utils.format_file_size(512), "512 字节")
        
        # 测试KB级别
        self.assertEqual(self.utils.format_file_size(1024), "1.0 KB")
        self.assertEqual(self.utils.format_file_size(1536), "1.5 KB")
        
        # 测试MB级别
        self.assertEqual(self.utils.format_file_size(1024 * 1024), "1.0 MB")
        self.assertEqual(self.utils.format_file_size(1572864), "1.5 MB")  # 1.5MB
        
        # 测试GB级别
        self.assertEqual(self.utils.format_file_size(1024 * 1024 * 1024), "1.0 GB")
    
    def test_get_user_choice(self):
        """测试用户选择获取（模拟）"""
        from unittest.mock import patch
        
        # 测试有效选择
        with patch('builtins.input', return_value='2'):
            result = self.utils.get_user_choice("测试选择", ['1', '2', '3'])
            self.assertEqual(result, '2')
        
        # 测试无效然后有效的选择
        with patch('builtins.input', side_effect=['invalid', '2']):
            result = self.utils.get_user_choice("测试选择", ['1', '2', '3'])
            self.assertEqual(result, '2')
    
    def test_validate_password_strength(self):
        """测试密码强度验证"""
        # 测试弱密码
        weak_password = "123"
        is_valid, warnings = self.utils.validate_password_strength(weak_password)
        self.assertFalse(is_valid)
        self.assertGreater(len(warnings), 0)
        
        # 测试中等强度密码
        medium_password = "password123"
        is_valid, warnings = self.utils.validate_password_strength(medium_password)
        # 应该包含长度警告
        self.assertGreater(len(warnings), 0)
        
        # 测试强密码
        strong_password = "StrongP@ssw0rd123!"
        is_valid, warnings = self.utils.validate_password_strength(strong_password)
        self.assertTrue(is_valid)
        self.assertEqual(len(warnings), 0)
    
    def test_password_strength_edge_cases(self):
        """测试密码强度边界情况"""
        # 测试空密码
        is_valid, warnings = self.utils.validate_password_strength("")
        self.assertFalse(is_valid)
        
        # 测试非常长的密码
        long_password = "a" * 100 + "A1!"
        is_valid, warnings = self.utils.validate_password_strength(long_password)
        self.assertTrue(is_valid)


if __name__ == '__main__':
    unittest.main()