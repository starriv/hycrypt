#!/usr/bin/env python3
"""
交互式模式集成测试
"""

import unittest
import sys
import os
import tempfile
import io
import shutil
from unittest.mock import patch, MagicMock

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from main import EncryptDecryptApp, interactive_mode, print_menu, Utils
from utils import Utils


class TestInteractiveMode(unittest.TestCase):
    """交互式模式测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "interactive_test_password"
        self.app = EncryptDecryptApp()
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    @patch('builtins.input')
    def test_menu_display(self, mock_input):
        """测试菜单显示"""
        # 模拟用户选择退出
        mock_input.side_effect = ['3']
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            try:
                interactive_mode(self.app)
            except SystemExit:
                pass
        
        # 验证菜单显示
        output = mock_stdout.getvalue()
        self.assertIn("文件加密解密工具", output)
        self.assertIn("1. 加密文件", output)
        self.assertIn("2. 解密文件", output)
        self.assertIn("3. 退出程序", output)
    
    @patch('builtins.input')
    def test_interactive_encryption_flow(self, mock_input):
        """测试交互式加密流程"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "interactive_test.txt")
        original_content = "Interactive test content"
        with open(test_file, 'w') as f:
            f.write(original_content)
        
        # 模拟用户输入序列：选择加密 -> 输入文件 -> 输入密码 -> 确认密码 -> 退出
        mock_input.side_effect = [
            '1',                    # 选择加密
            test_file,              # 输入文件路径
            self.test_password,     # 输入密码
            self.test_password,     # 确认密码
            '3',                    # 退出
            ''                      # 按回车继续
        ]
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            interactive_mode(self.app)
        
        # 验证输出包含成功信息
        output = mock_stdout.getvalue()
        self.assertIn("加密完成", output)
        
        # 验证加密文件存在
        encrypted_file = test_file + ".enc"
        self.assertTrue(os.path.exists(encrypted_file))
    
    @patch('builtins.input')
    def test_interactive_decryption_flow(self, mock_input):
        """测试交互式解密流程"""
        # 创建并加密测试文件
        test_file = os.path.join(self.test_dir, "interactive_decrypt_test.txt")
        original_content = "Interactive decrypt test content"
        with open(test_file, 'w') as f:
            f.write(original_content)
        
        # 先加密文件
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 模拟用户输入序列：选择解密 -> 输入加密文件 -> 输入密码 -> 退出
        mock_input.side_effect = [
            '2',                    # 选择解密
            encrypted_path,         # 输入加密文件路径
            self.test_password,     # 输入密码
            '3',                    # 退出
            ''                      # 按回车继续
        ]
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            interactive_mode(self.app)
        
        # 验证输出包含成功信息
        output = mock_stdout.getvalue()
        self.assertIn("解密完成", output)
        
        # 验证解密文件存在且内容正确
        self.assertTrue(os.path.exists(test_file))
        with open(test_file, 'r') as f:
            decrypted_content = f.read()
        self.assertEqual(decrypted_content, original_content)
    
    @patch('builtins.input')
    def test_interactive_directory_encryption(self, mock_input):
        """测试交互式目录加密"""
        # 创建测试目录结构
        test_dir = os.path.join(self.test_dir, "interactive_project")
        os.makedirs(test_dir)
        
        # 创建测试文件
        test_file = os.path.join(test_dir, "project_file.txt")
        with open(test_file, 'w') as f:
            f.write("Project file content")
        
        # 模拟用户输入序列：选择加密 -> 输入目录 -> 输入密码 -> 确认密码 -> 退出
        mock_input.side_effect = [
            '1',                    # 选择加密
            test_dir,               # 输入目录路径
            self.test_password,     # 输入密码
            self.test_password,     # 确认密码
            '3',                    # 退出
            ''                      # 按回车继续
        ]
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            interactive_mode(self.app)
        
        # 验证输出包含目录相关信息
        output = mock_stdout.getvalue()
        self.assertIn("目录", output)
        self.assertIn("加密完成", output)
        
        # 验证加密文件存在（应该生成带日期的压缩文件）
        import glob
        encrypted_pattern = os.path.join(self.test_dir, "20250923-*interactive_project.zip.enc")
        encrypted_files = glob.glob(encrypted_pattern)
        self.assertGreater(len(encrypted_files), 0)
    
    @patch('builtins.input')
    def test_interactive_error_handling(self, mock_input):
        """测试交互式错误处理"""
        # 模拟输入不存在的文件
        nonexistent_file = "/path/to/nonexistent/file.txt"
        
        mock_input.side_effect = [
            '1',                    # 选择加密
            nonexistent_file,       # 输入不存在的文件
            '3',                    # 退出
            ''                      # 按回车继续
        ]
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            interactive_mode(self.app)
        
        # 验证错误处理
        output = mock_stdout.getvalue()
        self.assertIn("不存在", output)
    
    @patch('builtins.input')
    def test_interactive_password_mismatch(self, mock_input):
        """测试交互式密码不匹配处理"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "password_mismatch_test.txt")
        with open(test_file, 'w') as f:
            f.write("Password mismatch test content")
        
        # 模拟密码不匹配
        mock_input.side_effect = [
            '1',                    # 选择加密
            test_file,              # 输入文件路径
            "password123",          # 输入密码
            "different456",         # 输入不同的确认密码
            "password123",          # 重新输入相同密码
            "password123",          # 确认密码
            '3',                    # 退出
            ''                      # 按回车继续
        ]
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            interactive_mode(self.app)
        
        # 验证密码不匹配处理
        output = mock_stdout.getvalue()
        self.assertIn("密码不一致", output)
        self.assertIn("密码确认通过", output)  # 最终应该成功
    
    @patch('builtins.input')
    def test_interactive_exit(self, mock_input):
        """测试交互式退出功能"""
        # 模拟直接退出
        mock_input.side_effect = ['3']
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            interactive_mode(self.app)
        
        # 验证退出信息
        output = mock_stdout.getvalue()
        self.assertIn("再见", output)
    
    def test_utils_get_user_choice(self):
        """测试工具函数的用户选择"""
        utils = Utils()
        
        # 测试有效的选择
        with patch('builtins.input', return_value='2'):
            choice = utils.get_user_choice("测试选择", ['1', '2', '3'])
            self.assertEqual(choice, '2')
        
        # 测试无效然后有效的选择
        with patch('builtins.input', side_effect=['invalid', '2']):
            choice = utils.get_user_choice("测试选择", ['1', '2', '3'])
            self.assertEqual(choice, '2')
    
    def test_utils_file_info_display(self):
        """测试工具函数的文件信息显示"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "info_display_test.txt")
        test_content = "Test content for info display"
        with open(test_file, 'w', encoding='utf-8') as f:
            f.write(test_content)
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            utils = Utils()
            utils.show_file_info(test_file)
        
        # 验证输出包含文件信息
        output = mock_stdout.getvalue()
        self.assertIn("文件:", output)
        self.assertIn("大小:", output)
        self.assertIn("算法:", output)
        self.assertIn("AES-256-CBC + Argon2id", output)
    
    def test_utils_directory_info_display(self):
        """测试工具函数的目录信息显示"""
        # 创建测试目录
        test_dir = os.path.join(self.test_dir, "dir_info_test")
        os.makedirs(test_dir)
        
        # 创建测试文件
        test_file = os.path.join(test_dir, "test_file.txt")
        with open(test_file, 'w') as f:
            f.write("Directory info test content")
        
        # 捕获输出
        with patch('sys.stdout', new_callable=io.StringIO) as mock_stdout:
            self.app.show_directory_info(test_dir)
        
        # 验证输出包含目录信息
        output = mock_stdout.getvalue()
        self.assertIn("目录:", output)
        self.assertIn("文件数量:", output)
        self.assertIn("总大小:", output)
        self.assertIn("算法:", output)


if __name__ == '__main__':
    unittest.main()