#!/usr/bin/env python3
"""
命令行界面集成测试
"""

import unittest
import sys
import os
import tempfile
import subprocess
import shutil

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))


class TestCommandLineInterface(unittest.TestCase):
    """命令行界面测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "cli_test_password"
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def run_command(self, args, input_text=None):
        """运行命令并返回结果"""
        cmd = [sys.executable, 'main.py'] + args
        result = subprocess.run(
            cmd,
            input=input_text,
            capture_output=True,
            text=True,
            cwd=os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        )
        return result
    
    def test_basic_encryption_cli(self):
        """测试基本命令行加密"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "cli_test.txt")
        with open(test_file, 'w') as f:
            f.write("CLI test content")
        
        # 使用命令行加密
        result = self.run_command([
            '-e', test_file,
            '-p', self.test_password
        ])
        
        # 验证命令成功
        self.assertEqual(result.returncode, 0)
        self.assertIn("加密完成", result.stdout)
        
        # 验证加密文件存在
        encrypted_file = test_file + ".enc"
        self.assertTrue(os.path.exists(encrypted_file))
    
    def test_basic_decryption_cli(self):
        """测试基本命令行解密"""
        # 创建并加密测试文件
        test_file = os.path.join(self.test_dir, "cli_decrypt_test.txt")
        original_content = "CLI decrypt test content"
        with open(test_file, 'w') as f:
            f.write(original_content)
        
        # 先加密
        encrypt_result = self.run_command([
            '-e', test_file,
            '-p', self.test_password
        ])
        self.assertEqual(encrypt_result.returncode, 0)
        
        # 使用命令行解密
        encrypted_file = test_file + ".enc"
        result = self.run_command([
            '-d', encrypted_file,
            '-p', self.test_password
        ])
        
        # 验证命令成功
        self.assertEqual(result.returncode, 0)
        self.assertIn("解密完成", result.stdout)
        
        # 验证解密文件存在且内容正确
        self.assertTrue(os.path.exists(test_file))
        with open(test_file, 'r') as f:
            decrypted_content = f.read()
        self.assertEqual(decrypted_content, original_content)
    
    def test_custom_output_filename(self):
        """测试自定义输出文件名"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "custom_output_test.txt")
        with open(test_file, 'w') as f:
            f.write("Custom output test content")
        
        custom_encrypted_name = os.path.join(self.test_dir, "my_secret_file.enc")
        
        # 使用自定义输出文件名加密
        result = self.run_command([
            '-e', test_file,
            '-p', self.test_password,
            '-o', custom_encrypted_name
        ])
        
        # 验证命令成功
        self.assertEqual(result.returncode, 0)
        
        # 验证自定义输出文件存在
        self.assertTrue(os.path.exists(custom_encrypted_name))
        self.assertFalse(os.path.exists(test_file + ".enc"))  # 不应该创建默认名称
        
        # 验证可以正常解密
        decrypt_result = self.run_command([
            '-d', custom_encrypted_name,
            '-p', self.test_password
        ])
        self.assertEqual(decrypt_result.returncode, 0)
    
    def test_directory_encryption_cli(self):
        """测试命令行目录加密"""
        # 创建测试目录
        test_dir = os.path.join(self.test_dir, "cli_test_project")
        os.makedirs(test_dir)
        
        # 创建测试文件
        test_file = os.path.join(test_dir, "project_file.txt")
        with open(test_file, 'w') as f:
            f.write("Project file content")
        
        # 使用命令行加密目录
        result = self.run_command([
            '-e', test_dir,
            '-p', self.test_password
        ])
        
        # 验证命令成功
        self.assertEqual(result.returncode, 0)
        self.assertIn("目录", result.stdout)
        
        # 验证加密文件存在（应该生成带日期的压缩文件）
        import glob
        encrypted_pattern = os.path.join(self.test_dir, "20250923-*cli_test_project.zip.enc")
        encrypted_files = glob.glob(encrypted_pattern)
        self.assertGreater(len(encrypted_files), 0)
    
    def test_help_command(self):
        """测试帮助命令"""
        # 测试基本帮助
        result = self.run_command(['-h'])
        
        # 验证帮助信息包含关键内容
        self.assertEqual(result.returncode, 0)
        self.assertIn("文件加密解密工具", result.stdout)
        self.assertIn("-e", result.stdout)
        self.assertIn("-d", result.stdout)
        self.assertIn("-p", result.stdout)
        self.assertIn("-o", result.stdout)
    
    def test_error_handling_nonexistent_file(self):
        """测试不存在的文件错误处理"""
        nonexistent_file = "/path/to/nonexistent/file.txt"
        
        # 尝试加密不存在的文件
        result = self.run_command([
            '-e', nonexistent_file,
            '-p', self.test_password
        ])
        
        # 验证命令失败
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("不存在", result.stdout)
    
    def test_error_handling_wrong_password(self):
        """测试错误密码处理"""
        # 创建并加密测试文件
        test_file = os.path.join(self.test_dir, "wrong_pass_test.txt")
        with open(test_file, 'w') as f:
            f.write("Wrong password test content")
        
        # 先加密
        encrypt_result = self.run_command([
            '-e', test_file,
            '-p', self.test_password
        ])
        self.assertEqual(encrypt_result.returncode, 0)
        
        # 尝试用错误密码解密
        encrypted_file = test_file + ".enc"
        result = self.run_command([
            '-d', encrypted_file,
            '-p', "wrong_password"
        ])
        
        # 验证命令失败
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("失败", result.stdout)
    
    def test_parameter_validation(self):
        """测试参数验证"""
        # 测试同时指定加密和解密
        result = self.run_command([
            '-e', 'file1.txt',
            '-d', 'file2.enc'
        ])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("不能同时", result.stdout)
        
        # 测试不指定操作 - 应该成功运行主程序
        result = self.run_command([])
        self.assertEqual(result.returncode, 0)  # 应该成功运行
    
    def test_quiet_mode(self):
        """测试安静模式"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "quiet_test.txt")
        with open(test_file, 'w') as f:
            f.write("Quiet mode test content")
        
        # 使用安静模式加密
        result = self.run_command([
            '-e', test_file,
            '-p', self.test_password,
            '-q'
        ])
        
        # 验证命令成功（安静模式输出较少）
        self.assertEqual(result.returncode, 0)
        # 安静模式下输出应该较少
        self.assertLess(len(result.stdout), 100)
    
    def test_binary_file_handling(self):
        """测试二进制文件处理"""
        # 创建二进制测试文件
        test_file = os.path.join(self.test_dir, "binary_test.bin")
        binary_content = os.urandom(1024)  # 1KB 随机数据
        
        with open(test_file, 'wb') as f:
            f.write(binary_content)
        
        # 加密二进制文件
        encrypt_result = self.run_command([
            '-e', test_file,
            '-p', self.test_password
        ])
        self.assertEqual(encrypt_result.returncode, 0)
        
        # 解密二进制文件
        encrypted_file = test_file + ".enc"
        decrypt_result = self.run_command([
            '-d', encrypted_file,
            '-p', self.test_password
        ])
        self.assertEqual(decrypt_result.returncode, 0)
        
        # 验证解密内容正确
        with open(test_file, 'rb') as f:
            decrypted_content = f.read()
        self.assertEqual(decrypted_content, binary_content)


class TestCLIInteractiveMode(unittest.TestCase):
    """交互式模式命令行测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "interactive_test_password"
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def run_interactive_command(self, input_commands):
        """运行交互式命令"""
        cmd = [sys.executable, 'main.py']
        result = subprocess.run(
            cmd,
            input=input_commands,
            capture_output=True,
            text=True,
            cwd=os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        )
        return result
    
    def test_interactive_encryption(self):
        """测试交互式加密"""
        # 创建测试文件
        test_file = os.path.join(self.test_dir, "interactive_test.txt")
        with open(test_file, 'w') as f:
            f.write("Interactive test content")
        
        # 模拟交互式输入
        input_commands = f"1\n{test_file}\n{self.test_password}\n{self.test_password}\n3\n"
        
        result = self.run_interactive_command(input_commands)
        
        # 验证交互成功
        self.assertEqual(result.returncode, 0)
        self.assertIn("加密完成", result.stdout)
        
        # 验证加密文件存在
        encrypted_file = test_file + ".enc"
        self.assertTrue(os.path.exists(encrypted_file))
    
    def test_interactive_decryption(self):
        """测试交互式解密"""
        # 创建并加密测试文件
        test_file = os.path.join(self.test_dir, "interactive_decrypt_test.txt")
        original_content = "Interactive decrypt test content"
        with open(test_file, 'w') as f:
            f.write(original_content)
        
        # 先加密
        encrypt_input = f"1\n{test_file}\n{self.test_password}\n{self.test_password}\n3\n"
        encrypt_result = self.run_interactive_command(encrypt_input)
        self.assertEqual(encrypt_result.returncode, 0)
        
        # 交互式解密
        encrypted_file = test_file + ".enc"
        decrypt_input = f"2\n{encrypted_file}\n{self.test_password}\n3\n"
        decrypt_result = self.run_interactive_command(decrypt_input)
        
        # 验证解密成功
        self.assertEqual(decrypt_result.returncode, 0)
        self.assertIn("解密完成", decrypt_result.stdout)
        
        # 验证解密内容正确
        with open(test_file, 'r') as f:
            decrypted_content = f.read()
        self.assertEqual(decrypted_content, original_content)


if __name__ == '__main__':
    unittest.main()