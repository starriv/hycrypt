#!/usr/bin/env python3
"""
hycrypt-py - 文件加密解密工具
提供交互式和命令行两种操作模式
"""

import os
import sys
import argparse
import getpass

from constants import (
    ENCRYPTED_FILE_EXTENSION, RESTORED_FILE_SUFFIX,
    DIRECTORY_ARCHIVE_SUFFIX
)
from crypto import CryptoManager
from archive import ArchiveManager
from utils import Utils


class EncryptDecryptApp:
    """hycrypt-py 加密解密应用程序主类"""
    
    def __init__(self):
        self.crypto_manager = CryptoManager()
        self.archive_manager = ArchiveManager()
        self.utils = Utils()
    
    def encrypt_file(self, file_path: str, password: str) -> str:
        """
        加密文件或目录
        
        Args:
            file_path: 文件或目录路径
            password: 加密密码
            
        Returns:
            加密文件路径
            
        Raises:
            Exception: 加密失败时抛出异常
        """
        # 检查是否为目录
        if self.archive_manager.is_directory(file_path):
            return self._encrypt_directory(file_path, password)
        else:
            return self._encrypt_single_file(file_path, password)
    
    def _encrypt_directory(self, directory_path: str, password: str) -> str:
        """加密目录"""
        print(f"📁 检测到目录，正在压缩: {directory_path}")
        
        # 创建目录压缩文件
        archive_path = self.archive_manager.create_directory_archive(directory_path)
        print(f"✅ 目录压缩完成: {archive_path}")
        
        try:
            # 递归加密压缩文件
            encrypted_path = self._encrypt_single_file(archive_path, password)
            
            # 清理临时压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
                print(f"🗑️  临时压缩文件已清理: {archive_path}")
            
            return encrypted_path
            
        except Exception as e:
            # 清理临时压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
            raise Exception(f"目录加密失败: {e}")
    
    def _encrypt_single_file(self, file_path: str, password: str) -> str:
        """加密单个文件"""
        # 加密文件数据
        encrypted_data = self.crypto_manager.encrypt_file_data(file_path, password)
        
        # 写入加密文件
        encrypted_file_path = file_path + ENCRYPTED_FILE_EXTENSION
        with open(encrypted_file_path, 'wb') as f:
            f.write(encrypted_data)
        
        return encrypted_file_path
    
    def decrypt_file(self, encrypted_file_path: str, password: str) -> str:
        """
        解密文件
        
        Args:
            encrypted_file_path: 加密文件路径
            password: 解密密码
            
        Returns:
            解密文件路径
            
        Raises:
            Exception: 解密失败时抛出异常
        """
        # 读取加密文件
        with open(encrypted_file_path, 'rb') as f:
            encrypted_data = f.read()
        
        # 解密数据
        plaintext = self.crypto_manager.decrypt_file_data(encrypted_data, password)
        
        # 确定输出文件名
        if encrypted_file_path.endswith(ENCRYPTED_FILE_EXTENSION):
            decrypted_file_path = encrypted_file_path[:-len(ENCRYPTED_FILE_EXTENSION)]
        else:
            decrypted_file_path = encrypted_file_path + RESTORED_FILE_SUFFIX
        
        # 写入解密文件
        with open(decrypted_file_path, 'wb') as f:
            f.write(plaintext)
        
        # 检查是否为压缩文件并解压
        if decrypted_file_path.endswith(DIRECTORY_ARCHIVE_SUFFIX):
            return self._handle_archive_decryption(decrypted_file_path)
        
        return decrypted_file_path
    
    def _handle_archive_decryption(self, archive_path: str) -> str:
        """处理压缩文件解密
        
        Returns:
            解压后的目录路径
        """
        try:
            print(f"📁 检测到压缩文件，正在解压: {archive_path}")
            extract_dir = self.archive_manager.extract_directory_archive(archive_path)
            print(f"✅ 压缩文件解压完成，解压到: {extract_dir}")
            
            # 清理临时压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
                print(f"🗑️  临时压缩文件已清理: {archive_path}")
            
            return extract_dir
        except Exception as e:
            print(f"⚠️  压缩文件解压失败: {e}")
            print(f"💡 解密后的压缩文件保留在: {archive_path}")
            return archive_path
    
    def show_file_info(self, filepath: str) -> None:
        """显示文件信息"""
        self.utils.show_file_info(filepath)
    
    def show_directory_info(self, directory_path: str) -> None:
        """显示目录信息"""
        info = self.archive_manager.get_directory_info(directory_path)
        print(f"📁 目录: {directory_path}")
        print(f"📊 文件数量: {info['file_count']} 个")
        print(f"📊 总大小: {info['total_size']:,} 字节 ({info['total_size']/1024:.1f} KB)")
        print(f"🔐 算法: AES-256-CBC + Argon2id")


def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='hycrypt-py - 文件加密解密工具，支持AES-256-Argon2id加密',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
使用示例:
  # 交互式界面
  python main.py
  
  # 命令行加密
  python main.py -e file.txt -p password
  
  # 命令行解密  
  python main.py -d file.txt.enc -p password
  
  # 指定输出文件名
  python main.py -e file.txt -p password -o encrypted.bin
        """
    )
    
    # 操作模式
    parser.add_argument('-e', '--encrypt', metavar='FILE',
                       help='要加密的文件路径')
    parser.add_argument('-d', '--decrypt', metavar='FILE', 
                       help='要解密的文件路径')
    
    # 密码选项
    parser.add_argument('-p', '--password', 
                       help='加密/解密密码 (如果不提供，将提示输入)')
    
    # 输出选项
    parser.add_argument('-o', '--output', 
                       help='输出文件路径 (可选)')
    
    # 其他选项
    parser.add_argument('-q', '--quiet', action='store_true',
                       help='安静模式，减少输出信息')
    parser.add_argument('-v', '--verbose', action='store_true', 
                       help='详细模式，显示更多信息')
    
    return parser.parse_args()


def command_line_mode(app: EncryptDecryptApp, args) -> bool:
    """命令行模式"""
    try:
        # 获取密码
        if args.password:
            password = args.password
        else:
            if args.encrypt:
                password = Utils().get_password("请输入加密密码 (确认): ")
            else:
                password = getpass.getpass("请输入解密密码: ")
        
        if not password:
            print("❌ 密码不能为空")
            return False
        
        # 执行加密或解密
        if args.encrypt:
            # 检查文件或目录是否存在
            if not os.path.exists(args.encrypt):
                print(f"❌ 路径 '{args.encrypt}' 不存在")
                return False
            
            # 显示信息
            if not args.quiet:
                if ArchiveManager().is_directory(args.encrypt):
                    app.show_directory_info(args.encrypt)
                else:
                    app.show_file_info(args.encrypt)
            
            # 执行加密
            encrypted_path = app.encrypt_file(args.encrypt, password)
            
            # 处理输出文件名
            if args.output:
                os.rename(encrypted_path, args.output)
                if not args.quiet:
                    print(f"✅ 加密完成: {args.output}")
            elif not args.quiet:
                print(f"✅ 加密完成: {encrypted_path}")
        
        elif args.decrypt:
            if not os.path.exists(args.decrypt):
                print(f"❌ 文件 '{args.decrypt}' 不存在")
                return False
            
            if not args.quiet:
                app.show_file_info(args.decrypt)
            
            # 执行解密
            decrypted_path = app.decrypt_file(args.decrypt, password)
            
            # 处理输出文件名
            if args.output:
                os.rename(decrypted_path, args.output)
                if not args.quiet:
                    print(f"✅ 解密完成: {args.output}")
            elif not args.quiet:
                print(f"✅ 解密完成: {decrypted_path}")
        
        return True
        
    except Exception as e:
        print(f"❌ 操作失败: {e}")
        return False


def interactive_mode(app: EncryptDecryptApp) -> None:
    """交互式模式"""
    print("🔐 欢迎使用 hycrypt-py 文件加密解密工具！")
    
    while True:
        print_menu()
        choice = Utils().get_user_choice("请选择操作", ['1', '2', '3'])
        
        if choice == '1':
            # 加密
            print("\n--- 文件/目录加密 ---")
            path = Utils().get_path_input("请输入要加密的文件或目录路径: ")
            if not path:
                continue
            
            # 显示信息
            if ArchiveManager().is_directory(path):
                app.show_directory_info(path)
            else:
                app.show_file_info(path)
            
            # 获取密码
            password = Utils().get_password("请输入加密密码: ")
            
            try:
                # 执行加密
                encrypted_path = app.encrypt_file(path, password)
                print(f"\n✅ 加密完成！加密文件: {encrypted_path}")
            except Exception as e:
                print(f"\n❌ 加密失败: {e}")
        
        elif choice == '2':
            # 解密
            print("\n--- 文件解密 ---")
            filename = Utils().get_filename_input(f"请输入要解密的文件名 ({ENCRYPTED_FILE_EXTENSION}): ")
            if not filename:
                continue
            
            if not filename.endswith(ENCRYPTED_FILE_EXTENSION):
                print(f"⚠️  注意: 解密文件通常以 {ENCRYPTED_FILE_EXTENSION} 为扩展名")
            
            app.show_file_info(filename)
            password = Utils().get_password("请输入解密密码: ")
            
            try:
                # 执行解密
                decrypted_path = app.decrypt_file(filename, password)
                print(f"\n✅ 解密完成！解密文件: {decrypted_path}")
                
                # 显示解密文件信息
                if os.path.exists(decrypted_path):
                    app.show_file_info(decrypted_path)
                    
            except Exception as e:
                print(f"\n❌ 解密失败: {e}")
                print("可能原因: 密码错误或文件损坏")
        
        elif choice == '3':
            print("\n👋 感谢使用，再见！")
            break
        
        input("\n按回车键继续...")


def print_menu():
    """显示选项菜单"""
    print("\n" + "="*50)
    print("           hycrypt-py 文件加密解密工具")
    print("="*50)
    print("1. 加密文件")
    print("2. 解密文件") 
    print("3. 退出程序")
    print("-"*50)


def main():
    """主函数"""
    app = EncryptDecryptApp()
    
    # 如果有命令行参数，使用命令行模式
    if len(sys.argv) > 1:
        args = parse_arguments()
        
        # 验证参数
        if args.encrypt and args.decrypt:
            print("❌ 不能同时指定加密和解密")
            return 1
        elif not args.encrypt and not args.decrypt:
            print("❌ 请指定 -e (加密) 或 -d (解密)")
            return 1
        
        # 执行命令行操作
        success = command_line_mode(app, args)
        return 0 if success else 1
    
    else:
        # 没有参数，进入交互式模式
        try:
            interactive_mode(app)
            return 0
        except KeyboardInterrupt:
            print("\n\n👋 程序被用户中断，再见！")
            return 0
        except Exception as e:
            print(f"\n❌ 程序发生错误: {e}")
            return 1


if __name__ == "__main__":
    sys.exit(main())