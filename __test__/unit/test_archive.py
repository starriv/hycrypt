#!/usr/bin/env python3
"""
归档模块单元测试
"""

import unittest
import sys
import os
import tempfile
import shutil
from datetime import datetime

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from archive import ArchiveManager
from constants import DIRECTORY_ARCHIVE_SUFFIX, DIRECTORY_ARCHIVE_NAME_PATTERN


class TestArchiveManager(unittest.TestCase):
    """测试归档管理器"""
    
    def setUp(self):
        """测试前的设置"""
        self.archive_manager = ArchiveManager()
        self.test_dir = tempfile.mkdtemp()
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_is_directory(self):
        """测试目录检查"""
        # 创建测试目录
        test_subdir = os.path.join(self.test_dir, "test_subdir")
        os.makedirs(test_subdir)
        
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "test_file.txt")
        with open(test_file, 'w') as f:
            f.write("test")
        
        # 验证检查
        self.assertTrue(self.archive_manager.is_directory(test_subdir))
        self.assertFalse(self.archive_manager.is_directory(test_file))
        self.assertFalse(self.archive_manager.is_directory("nonexistent"))
    
    def test_generate_archive_name(self):
        """测试归档文件名生成"""
        # 创建测试目录
        test_subdir = os.path.join(self.test_dir, "test_project")
        os.makedirs(test_subdir)
        
        # 生成归档文件名
        archive_name = self.archive_manager.generate_archive_name(test_subdir)
        
        # 验证格式
        self.assertIsInstance(archive_name, str)
        self.assertTrue(archive_name.endswith(DIRECTORY_ARCHIVE_SUFFIX))
        self.assertIn("test_project", archive_name)
        self.assertIn(datetime.now().strftime("%Y%m%d"), archive_name)
    
    def test_create_directory_archive_empty(self):
        """测试空目录归档"""
        # 创建空目录
        empty_dir = os.path.join(self.test_dir, "empty_dir")
        os.makedirs(empty_dir)
        
        # 归档空目录
        archive_path = self.archive_manager.create_directory_archive(empty_dir)
        
        # 验证归档文件存在
        self.assertTrue(os.path.exists(archive_path))
        self.assertTrue(archive_path.endswith(DIRECTORY_ARCHIVE_SUFFIX))
        
        # 验证归档文件大小（空目录应该很小）
        self.assertGreater(os.path.getsize(archive_path), 0)
    
    def test_create_directory_archive_with_files(self):
        """测试包含文件的目录归档"""
        # 创建测试目录结构
        test_dir = os.path.join(self.test_dir, "test_project")
        subdir1 = os.path.join(test_dir, "docs")
        subdir2 = os.path.join(test_dir, "src")
        
        os.makedirs(subdir1)
        os.makedirs(subdir2)
        
        # 创建测试文件
        files_to_create = [
            (os.path.join(test_dir, "readme.txt"), "Project readme"),
            (os.path.join(subdir1, "manual.txt"), "User manual"),
            (os.path.join(subdir2, "main.py"), "def main(): pass"),
            (os.path.join(subdir2, "utils.py"), "def helper(): pass")
        ]
        
        for file_path, content in files_to_create:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
        
        # 归档目录
        archive_path = self.archive_manager.create_directory_archive(test_dir)
        
        # 验证归档文件存在
        self.assertTrue(os.path.exists(archive_path))
        self.assertTrue(archive_path.endswith(DIRECTORY_ARCHIVE_SUFFIX))
        
        # 验证归档文件包含内容
        self.assertGreater(os.path.getsize(archive_path), 100)  # 应该比空目录大
    
    def test_extract_directory_archive(self):
        """测试归档解压"""
        # 创建测试目录和文件
        original_dir = os.path.join(self.test_dir, "original_project")
        os.makedirs(original_dir)
        
        test_file = os.path.join(original_dir, "test.txt")
        with open(test_file, 'w') as f:
            f.write("Test content")
        
        # 归档目录
        archive_path = self.archive_manager.create_directory_archive(original_dir)
        
        # 创建解压目录
        extract_dir = os.path.join(self.test_dir, "extracted")
        os.makedirs(extract_dir)
        
        # 解压归档
        extracted_path = self.archive_manager.extract_directory_archive(archive_path, extract_dir)
        
        # 验证解压结果
        self.assertTrue(os.path.exists(extracted_path))
        self.assertTrue(os.path.isdir(extracted_path))
        
        # 验证文件内容
        extracted_file = os.path.join(extracted_path, "test.txt")
        self.assertTrue(os.path.exists(extracted_file))
        
        with open(extracted_file, 'r') as f:
            content = f.read()
        self.assertEqual(content, "Test content")
    
    def test_get_directory_info(self):
        """测试获取目录信息"""
        # 创建测试目录结构
        test_dir = os.path.join(self.test_dir, "info_test")
        subdir1 = os.path.join(test_dir, "dir1")
        subdir2 = os.path.join(test_dir, "dir2")
        
        os.makedirs(subdir1)
        os.makedirs(subdir2)
        
        # 创建测试文件
        files_to_create = [
            (os.path.join(test_dir, "file1.txt"), "Content 1" * 100),
            (os.path.join(test_dir, "file2.txt"), "Content 2" * 200),
            (os.path.join(subdir1, "file3.txt"), "Content 3" * 50),
            (os.path.join(subdir2, "file4.txt"), "Content 4" * 150)
        ]
        
        total_size = 0
        for file_path, content in files_to_create:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            total_size += len(content.encode('utf-8'))
        
        # 获取目录信息
        info = self.archive_manager.get_directory_info(test_dir)
        
        # 验证信息
        self.assertIsInstance(info, dict)
        self.assertIn('file_count', info)
        self.assertIn('total_size', info)
        self.assertEqual(info['file_count'], 4)
        self.assertEqual(info['total_size'], total_size)
    
    def test_get_directory_info_empty(self):
        """测试空目录信息"""
        # 创建空目录
        empty_dir = os.path.join(self.test_dir, "empty_info_test")
        os.makedirs(empty_dir)
        
        # 获取空目录信息
        info = self.archive_manager.get_directory_info(empty_dir)
        
        # 验证结果
        self.assertEqual(info['file_count'], 0)
        self.assertEqual(info['total_size'], 0)
    
    def test_archive_error_handling(self):
        """测试归档错误处理"""
        # 测试不存在的目录
        with self.assertRaises(Exception):
            self.archive_manager.create_directory_archive("nonexistent_directory")
        
        # 测试无效的归档文件
        with self.assertRaises(Exception):
            self.archive_manager.extract_directory_archive("nonexistent.zip")


if __name__ == '__main__':
    unittest.main()