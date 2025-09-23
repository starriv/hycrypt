#!/usr/bin/env python3
"""
工具函数模块
提供各种辅助功能和工具函数
"""

import os
import getpass

from constants import (
    DEMO_DIR
)


class Utils:
    """工具类"""
    
    @staticmethod
    def ensure_demo_dir() -> str:
        """确保演示目录存在"""
        if not os.path.exists(DEMO_DIR):
            os.makedirs(DEMO_DIR)
        return DEMO_DIR
    
    @staticmethod
    def get_demo_path(filename: str) -> str:
        """获取演示目录中的文件路径"""
        Utils.ensure_demo_dir()
        return os.path.join(DEMO_DIR, filename)
    
    @staticmethod
    def is_encrypted_file(path: str) -> bool:
        """检查路径是否为加密文件"""
        from constants import ENCRYPTED_FILE_EXTENSION
        return path.endswith(ENCRYPTED_FILE_EXTENSION)
    
    @staticmethod
    def get_password(prompt: str = "请输入密码: ") -> str:
        """
        获取密码，带强度检查和二次确认
        
        Args:
            prompt: 密码提示文本
            
        Returns:
            用户输入的密码
        """
        while True:
            password = getpass.getpass(prompt)
            if not password:
                print("❌ 密码不能为空")
                continue
                
            if len(password) < 6:
                print("⚠️  密码长度建议至少6位")
                confirm = input("是否继续使用此密码？(y/N): ").lower()
                if confirm != 'y':
                    continue
            
            # 如果是加密操作（包含"确认"或"加密"字样），需要二次确认
            if "确认" in prompt or "加密" in prompt:
                password2 = getpass.getpass("请再次输入密码确认: ")
                if password != password2:
                    print("❌ 两次输入的密码不一致")
                    continue
                print("✅ 密码确认通过")
            
            return password
    
    @staticmethod
    def get_filename_input(prompt: str) -> str:
        """
        获取文件名输入，支持拖拽和自动补全
        
        Args:
            prompt: 输入提示
            
        Returns:
            文件名，如果无效返回 None
        """
        filename = input(prompt).strip().strip('"\'')  # 移除可能的引号
        if not filename:
            print("❌ 文件名不能为空")
            return None
        
        # 检查文件是否存在
        if not os.path.exists(filename):
            print(f"❌ 文件 '{filename}' 不存在")
            return None
        
        return filename
    
    @staticmethod
    def get_path_input(prompt: str) -> str:
        """
        获取文件或目录路径，支持拖拽和自动补全
        
        Args:
            prompt: 输入提示
            
        Returns:
            路径，如果无效返回 None
        """
        path = input(prompt).strip().strip('"\'')  # 移除可能的引号
        if not path:
            print("❌ 路径不能为空")
            return None
        
        # 检查路径是否存在
        if not os.path.exists(path):
            print(f"❌ 路径 '{path}' 不存在")
            return None
        
        return path
    
    @staticmethod
    def show_file_info(filepath: str) -> None:
        """
        显示文件信息
        
        Args:
            filepath: 文件路径
        """
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            print(f"📁 文件: {filepath}")
            print(f"📊 大小: {size:,} 字节 ({size/1024:.1f} KB)")
            print(f"🔐 算法: AES-256-CBC + Argon2id")
    
    @staticmethod
    def format_file_size(size_bytes: int) -> str:
        """
        格式化文件大小
        
        Args:
            size_bytes: 文件大小（字节）
            
        Returns:
            格式化的大小字符串
        """
        if size_bytes < 1024:
            return f"{size_bytes} 字节"
        elif size_bytes < 1024 * 1024:
            return f"{size_bytes/1024:.1f} KB"
        elif size_bytes < 1024 * 1024 * 1024:
            return f"{size_bytes/(1024*1024):.1f} MB"
        else:
            return f"{size_bytes/(1024*1024*1024):.1f} GB"
    
    @staticmethod
    def get_user_choice(prompt: str = "请选择操作", choices: list = None) -> str:
        """
        获取用户选择
        
        Args:
            prompt: 选择提示
            choices: 有效选择列表
            
        Returns:
            用户选择
        """
        if choices is None:
            choices = ['1', '2', '3']
        
        while True:
            choice = input(f"{prompt} ({'/'.join(choices)}): ").strip()
            if choice in choices:
                return choice
            print(f"❌ 无效选择，请输入 {'/'.join(choices)}")
    
    @staticmethod
    def validate_password_strength(password: str) -> tuple:
        """
        验证密码强度
        
        Args:
            password: 密码
            
        Returns:
            (是否有效, 警告信息) 元组
        """
        warnings = []
        
        if len(password) < 6:
            warnings.append("密码长度建议至少6位")
        
        if len(password) < 8:
            warnings.append("密码长度建议至少8位以获得更好的安全性")
        
        if not any(c.isupper() for c in password):
            warnings.append("建议包含大写字母")
        
        if not any(c.islower() for c in password):
            warnings.append("建议包含小写字母")
        
        if not any(c.isdigit() for c in password):
            warnings.append("建议包含数字")
        
        if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password):
            warnings.append("建议包含特殊字符")
        
        is_valid = len(warnings) == 0 or (len(warnings) == 1 and "密码长度建议至少8位" in warnings)
        
        return is_valid, warnings