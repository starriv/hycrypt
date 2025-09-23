#!/usr/bin/env python3
"""
加密解密集成测试
测试整个加密解密流程
"""

import unittest
import sys
import os
import tempfile
import shutil

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from main import EncryptDecryptApp


class TestEncryptionIntegration(unittest.TestCase):
    """加密解密集成测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.app = EncryptDecryptApp()
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "integration_test_password_123"
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_file_encryption_decryption_workflow(self):
        """测试文件加密解密完整流程"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "workflow_test.txt")
        original_content = "This is integration test content for encryption workflow.\n"
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write(original_content)
        
        # 加密文件
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        self.assertTrue(encrypted_path.endswith('.enc'))
        
        # 验证加密文件与原始文件不同
        with open(encrypted_path, 'rb') as f:
            encrypted_content = f.read()
        with open(test_file, 'rb') as f:
            original_bytes = f.read()
        
        self.assertNotEqual(encrypted_content, original_bytes)
        
        # 解密文件
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证解密文件存在
        self.assertTrue(os.path.exists(decrypted_path))
        self.assertEqual(decrypted_path, test_file)  # 应该恢复原文件名
        
        # 验证解密内容与原始内容一致
        with open(decrypted_path, 'r', encoding='utf-8') as f:
            decrypted_content = f.read()
        
        self.assertEqual(decrypted_content, original_content)
    
    def test_directory_encryption_decryption_workflow(self):
        """测试目录加密解密完整流程"""
        # 创建测试目录结构
        test_dir = os.path.join(self.test_dir, "project_dir")
        subdir1 = os.path.join(test_dir, "docs")
        subdir2 = os.path.join(test_dir, "src")
        
        os.makedirs(subdir1)
        os.makedirs(subdir2)
        
        # 创建测试文件
        files_to_create = [
            (os.path.join(test_dir, "readme.txt"), "Project readme content"),
            (os.path.join(subdir1, "manual.txt"), "User manual content"),
            (os.path.join(subdir2, "main.py"), "def main():\n    print('Hello')"),
            (os.path.join(subdir2, "utils.py"), "def helper():\n    return True")
        ]
        
        for file_path, content in files_to_create:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
        
        # 记录原始文件信息
        original_files = []
        for root, dirs, files in os.walk(test_dir):
            for file in files:
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    original_files.append((file_path, f.read()))
        
        # 加密目录
        encrypted_path = self.app.encrypt_file(test_dir, self.test_password)
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        self.assertTrue(encrypted_path.endswith('.zip.enc'))
        
        # 移除原始目录
        shutil.rmtree(test_dir)
        self.assertFalse(os.path.exists(test_dir))
        
        # 解密目录
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证解压目录存在
        self.assertTrue(os.path.exists(decrypted_path))
        self.assertTrue(os.path.isdir(decrypted_path))
        
        # 验证所有文件和目录结构完整
        for original_file_path, original_content in original_files:
            # 构建解压后的文件路径
            relative_path = os.path.relpath(original_file_path, test_dir)
            decrypted_file_path = os.path.join(decrypted_path, relative_path)
            
            # 验证文件存在
            self.assertTrue(os.path.exists(decrypted_file_path),
                          f"文件不存在: {decrypted_file_path}")
            
            # 验证文件内容
            with open(decrypted_file_path, 'r', encoding='utf-8') as f:
                decrypted_content = f.read()
            
            self.assertEqual(decrypted_content, original_content,
                           f"文件内容不匹配: {decrypted_file_path}")
    
    def test_password_verification(self):
        """测试密码验证机制"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "password_test.txt")
        with open(test_file, 'w') as f:
            f.write("password test content")
        
        # 加密文件
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        
        # 使用正确密码解密 - 应该成功
        decrypted_path_correct = self.app.decrypt_file(encrypted_path, self.test_password)
        self.assertTrue(os.path.exists(decrypted_path_correct))
        
        # 使用错误密码解密 - 应该失败
        with self.assertRaises(Exception):
            self.app.decrypt_file(encrypted_path, "wrong_password")
    
    def test_multiple_files_encryption(self):
        """测试多个文件独立加密"""
        # 创建多个测试文件
        test_files = []
        for i in range(3):
            test_file = os.path.join(self.test_dir, f"multi_test_{i}.txt")
            content = f"Content of file {i}\n"
            with open(test_file, 'w', encoding='utf-8') as f:
                f.write(content)
            test_files.append((test_file, content))
        
        # 分别加密所有文件
        encrypted_paths = []
        for test_file, _ in test_files:
            encrypted_path = self.app.encrypt_file(test_file, self.test_password)
            encrypted_paths.append(encrypted_path)
        
        # 验证所有加密文件存在
        for encrypted_path in encrypted_paths:
            self.assertTrue(os.path.exists(encrypted_path))
        
        # 分别解密所有文件
        for i, (original_file, original_content) in enumerate(test_files):
            encrypted_path = encrypted_paths[i]
            decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
            
            # 验证解密文件
            self.assertTrue(os.path.exists(decrypted_path))
            with open(decrypted_path, 'r', encoding='utf-8') as f:
                decrypted_content = f.read()
            self.assertEqual(decrypted_content, original_content)
    
    def test_binary_file_encryption(self):
        """测试二进制文件加密解密"""
        # 创建二进制测试文件
        test_file = os.path.join(self.test_dir, "binary_test.bin")
        binary_content = os.urandom(1024)  # 1KB 随机二进制数据
        
        with open(test_file, 'wb') as f:
            f.write(binary_content)
        
        # 加密二进制文件
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 解密二进制文件
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证解密文件
        self.assertTrue(os.path.exists(decrypted_path))
        
        # 验证二进制内容一致
        with open(decrypted_path, 'rb') as f:
            decrypted_content = f.read()
        
        self.assertEqual(decrypted_content, binary_content)
    
    def test_empty_file_encryption(self):
        """测试空文件加密解密"""
        # 创建空测试文件
        test_file = os.path.join(self.test_dir, "empty_test.txt")
        with open(test_file, 'w') as f:
            pass  # 创建空文件
        
        # 加密空文件
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 解密空文件
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证解密文件存在且为空
        self.assertTrue(os.path.exists(decrypted_path))
        self.assertEqual(os.path.getsize(decrypted_path), 0)


class TestEncryptionEdgeCases(unittest.TestCase):
    """加密解密边界情况测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.app = EncryptDecryptApp()
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "edge_case_password"
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_special_characters_in_filename(self):
        """测试文件名中包含特殊字符"""
        # 创建包含特殊字符的文件名
        special_file = os.path.join(self.test_dir, "test_file_with_特殊字符_and_spaces.txt")
        content = "Content with special characters: 你好世界 🌍"
        
        with open(special_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        # 加密文件
        encrypted_path = self.app.encrypt_file(special_file, self.test_password)
        
        # 验证加密成功
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 解密文件
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证解密内容
        self.assertTrue(os.path.exists(decrypted_path))
        with open(decrypted_path, 'r', encoding='utf-8') as f:
            decrypted_content = f.read()
        
        self.assertEqual(decrypted_content, content)
    
    def test_very_large_file(self):
        """测试大文件处理"""
        # 创建 10MB 的大文件
        test_file = os.path.join(self.test_dir, "large_file.bin")
        large_content = os.urandom(10 * 1024 * 1024)  # 10MB
        
        with open(test_file, 'wb') as f:
            f.write(large_content)
        
        # 加密大文件
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        
        # 验证加密成功
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 解密大文件
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证解密成功
        self.assertTrue(os.path.exists(decrypted_path))
        
        # 验证内容完整
        with open(decrypted_path, 'rb') as f:
            decrypted_content = f.read()
        
        self.assertEqual(decrypted_content, large_content)
        self.assertEqual(len(decrypted_content), len(large_content))
    
    def test_nested_directory_structure(self):
        """测试深层嵌套目录结构"""
        # 创建深层嵌套目录
        deep_dir = os.path.join(self.test_dir, "level1", "level2", "level3", "level4", "level5")
        os.makedirs(deep_dir)
        
        # 在不同层级创建文件
        files_to_create = [
            (os.path.join(self.test_dir, "level1", "root.txt"), "Root level"),
            (os.path.join(self.test_dir, "level1", "level2", "level2.txt"), "Level 2"),
            (os.path.join(deep_dir, "deep.txt"), "Deep level file")
        ]
        
        for file_path, content in files_to_create:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
        
        # 加密整个目录结构
        root_dir = os.path.join(self.test_dir, "level1")
        encrypted_path = self.app.encrypt_file(root_dir, self.test_password)
        
        # 验证加密成功
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 移除原始目录
        shutil.rmtree(root_dir)
        
        # 解密目录结构
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        
        # 验证所有层级和文件都存在
        for original_file_path, original_content in files_to_create:
            # 构建相对路径
            relative_path = os.path.relpath(original_file_path, root_dir)
            decrypted_file_path = os.path.join(decrypted_path, relative_path)
            
            # 验证文件存在
            self.assertTrue(os.path.exists(decrypted_file_path),
                          f"文件不存在: {decrypted_file_path}")
            
            # 验证文件内容
            with open(decrypted_file_path, 'r', encoding='utf-8') as f:
                decrypted_content = f.read()
            self.assertEqual(decrypted_content, original_content)


if __name__ == '__main__':
    unittest.main()