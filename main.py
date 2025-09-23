#!/usr/bin/env python3
"""
hycrypt-py - 文件加密解密工具 (常量版本)
提供交互式和命令行两种操作模式，支持多语言
使用英文常量作为翻译键
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
from i18n import (
    _, init_locale, set_language, get_current_language,
    APP_TITLE, APP_WELCOME, APP_ENCRYPT_FILE, APP_DECRYPT_FILE, APP_EXIT_PROGRAM,
    MENU_FILE_ENCRYPTION, MENU_FILE_DECRYPTION,
    INPUT_ENCRYPT_PATH, INPUT_ENCRYPT_PASSWORD, INPUT_DECRYPT_FILENAME, INPUT_DECRYPT_PASSWORD,
    INPUT_FILENAME, INPUT_PATH, INPUT_PASSWORD, INPUT_PASSWORD_CONFIRM, INPUT_CHOICE,
    STATUS_ENCRYPT_COMPLETE, STATUS_DECRYPT_COMPLETE, STATUS_ENCRYPT_FAILED, STATUS_DECRYPT_FAILED,
    STATUS_PROGRAM_ERROR, STATUS_PRESS_ENTER_CONTINUE, STATUS_GOODBYE, STATUS_PROGRAM_INTERRUPTED,
    REASON_PASSWORD_ERROR,
    ARG_DESCRIPTION, ARG_ENCRYPT_PATH, ARG_DECRYPT_PATH, ARG_PASSWORD_HELP, ARG_OUTPUT_HELP,
    ARG_QUIET_HELP, ARG_VERBOSE_HELP, ARG_LANGUAGE_HELP,
    ERROR_BOTH_ENCRYPT_DECRYPT, ERROR_NO_ENCRYPT_DECRYPT, ERROR_PASSWORD_EMPTY,
    ERROR_PATH_NOT_EXIST, ERROR_FILE_NOT_EXIST, ERROR_OPERATION_FAILED, ERROR_FILENAME_EMPTY,
    ERROR_PATH_EMPTY, ERROR_INVALID_CHOICE,
    SUCCESS_ENCRYPT_COMPLETE, SUCCESS_DECRYPT_COMPLETE, SUCCESS_PASSWORD_CONFIRMED,
    SUCCESS_DIR_COMPRESSED, SUCCESS_ARCHIVE_EXTRACTED, SUCCESS_TEMP_CLEANED,
    FILE_DETECTED_DIR_COMPRESSING, FILE_DETECTED_ARCHIVE_EXTRACTING, FILE_ARCHIVE_EXTRACT_FAILED,
    FILE_ARCHIVE_EXTRACT_KEEP, FILE_TEMP_CLEANED,
    FILE_INFO_FILE, FILE_INFO_SIZE, FILE_INFO_DIR, FILE_INFO_COUNT, FILE_INFO_TOTAL_SIZE,
    FILE_INFO_ALGORITHM,
    WARNING_PASSWORD_LENGTH, WARNING_PASSWORD_STRENGTH, WARNING_DECRYPT_EXTENSION,
    WARNING_ARCHIVE_EXTRACT_FAILED,
    SIZE_BYTES, SIZE_KB, SIZE_MB, SIZE_GB,
    USAGE_EXAMPLES, USAGE_INTERACTIVE, USAGE_ENCRYPT_CLI, USAGE_DECRYPT_CLI, USAGE_OUTPUT_FILENAME,
    LANGUAGE_SELECT, LANGUAGE_EN, LANGUAGE_ZH, LANGUAGE_ES,
    OPERATION_SELECT,
    EXTENSION_NOTICE, EXTENSION_SUFFIX,
    TEST_COVERAGE, TEST_RUNNER, START_TESTS, ALL_TESTS_PASSED, SOME_TESTS_FAILED,
    RUN_ALL_TESTS, RUN_UNIT_TESTS, RUN_INTEGRATION_TESTS, RUN_PERFORMANCE_TESTS,
    RUN_SPECIFIC_TEST, RUN_LEGACY_TESTS, SHOW_TEST_COVERAGE, DETAILED_OUTPUT,
    ERROR_TEST_FILE_NOT_FOUND, ERROR_NO_TEST_FILES, ERROR_PYTEST_NOT_FOUND,
    ERROR_TEST_RUN_FAILED, RUN_TEST_COMMAND, RUN_TEST_FILE, SUCCESS_TEST_PASSED,
    ERROR_TEST_FAILED, ERROR_RUN_TEST_ERROR, RUN_LEGACY_TEST,
    OUTPUT_LABEL, ERROR_LABEL, TEST_RESULTS, RUN_LEGACY_FILES, TOTAL_TEST_FILES,
    TEST_SUMMARY, UNIT_TEST_COUNT, INTEGRATION_TEST_COUNT, PERFORMANCE_TEST_COUNT
)


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
        print(_(FILE_DETECTED_DIR_COMPRESSING) + directory_path)
        
        # 创建目录压缩文件
        archive_path = self.archive_manager.create_directory_archive(directory_path)
        print(_(SUCCESS_DIR_COMPRESSED) + archive_path)
        
        try:
            # 递归加密压缩文件
            encrypted_path = self._encrypt_single_file(archive_path, password)
            
            # 清理临时压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
                print(_(SUCCESS_TEMP_CLEANED) + archive_path)
            
            return encrypted_path
            
        except Exception as e:
            # 清理临时压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
            raise Exception(_(STATUS_ENCRYPT_FAILED) + str(e))
    
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
            print(_(FILE_DETECTED_ARCHIVE_EXTRACTING) + archive_path)
            extract_dir = self.archive_manager.extract_directory_archive(archive_path)
            print(_(SUCCESS_ARCHIVE_EXTRACTED) + extract_dir)
            
            # 清理临时压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
                print(_(SUCCESS_TEMP_CLEANED) + archive_path)
            
            return extract_dir
        except Exception as e:
            print(_(FILE_ARCHIVE_EXTRACT_FAILED) + str(e))
            print(_(FILE_ARCHIVE_EXTRACT_KEEP) + archive_path)
            return archive_path
    
    def show_file_info(self, filepath: str) -> None:
        """显示文件信息"""
        self.utils.show_file_info(filepath)
    
    def show_directory_info(self, directory_path: str) -> None:
        """显示目录信息"""
        info = self.archive_manager.get_directory_info(directory_path)
        print(_(FILE_INFO_DIR) + directory_path)
        print(_(FILE_INFO_COUNT) + str(info['file_count']) + _(" 个"))
        print(_(FILE_INFO_TOTAL_SIZE) + f"{info['total_size']:,}" + _(" 字节 (") + f"{info['total_size']/1024:.1f}" + _(" KB)"))
        print(_(FILE_INFO_ALGORITHM))


def parse_arguments():
    """解析命令行参数"""
    epilog_text = _(USAGE_EXAMPLES) + """
  # """ + _(USAGE_INTERACTIVE) + """
  python main.py
  
  # """ + _(USAGE_ENCRYPT_CLI) + """
  python main.py -e file.txt -p password
  
  # """ + _(USAGE_DECRYPT_CLI) + """  
  python main.py -d file.txt.enc -p password
  
  # """ + _(USAGE_OUTPUT_FILENAME) + """
  python main.py -e file.txt -p password -o encrypted.bin
        """
    
    parser = argparse.ArgumentParser(
        description=_(ARG_DESCRIPTION),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog_text
    )
    
    # 语言选择
    parser.add_argument('--lang', choices=['en', 'zh', 'es'], 
                       help=_(ARG_LANGUAGE_HELP))
    
    # 操作模式
    parser.add_argument('-e', '--encrypt', metavar='PATH',
                       help=_(ARG_ENCRYPT_PATH))
    parser.add_argument('-d', '--decrypt', metavar='PATH', 
                       help=_(ARG_DECRYPT_PATH))
    
    # 密码选项
    parser.add_argument('-p', '--password', metavar='PASSWORD',
                       help=_(ARG_PASSWORD_HELP))
    
    # 输出选项
    parser.add_argument('-o', '--output', metavar='PATH',
                       help=_(ARG_OUTPUT_HELP))
    
    # 其他选项
    parser.add_argument('-q', '--quiet', action='store_true',
                       help=_(ARG_QUIET_HELP))
    parser.add_argument('-v', '--verbose', action='store_true', 
                       help=_(ARG_VERBOSE_HELP))
    
    return parser.parse_args()


def command_line_mode(app: EncryptDecryptApp, args) -> bool:
    """命令行模式"""
    try:
        # 获取密码
        if args.password:
            password = args.password
        else:
            if args.encrypt:
                password = Utils().get_password(_(INPUT_ENCRYPT_PASSWORD))
            else:
                password = getpass.getpass(_(INPUT_DECRYPT_PASSWORD))
        
        if not password:
            print(_(ERROR_PASSWORD_EMPTY))
            return False
        
        # 执行加密或解密
        if args.encrypt:
            # 检查文件或目录是否存在
            if not os.path.exists(args.encrypt):
                print(_(ERROR_PATH_NOT_EXIST) + args.encrypt + _("' 不存在"))
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
                    print(_(SUCCESS_ENCRYPT_COMPLETE) + args.output)
            elif not args.quiet:
                print(_(SUCCESS_ENCRYPT_COMPLETE) + encrypted_path)
        
        elif args.decrypt:
            if not os.path.exists(args.decrypt):
                print(_(ERROR_FILE_NOT_EXIST) + args.decrypt + _("' 不存在"))
                return False
            
            if not args.quiet:
                app.show_file_info(args.decrypt)
            
            # 执行解密
            decrypted_path = app.decrypt_file(args.decrypt, password)
            
            # 处理输出文件名
            if args.output:
                os.rename(decrypted_path, args.output)
                if not args.quiet:
                    print(_(SUCCESS_DECRYPT_COMPLETE) + args.output)
            elif not args.quiet:
                print(_(SUCCESS_DECRYPT_COMPLETE) + decrypted_path)
        
        return True
        
    except Exception as e:
        print(_(ERROR_OPERATION_FAILED) + str(e))
        return False


def print_menu():
    """显示选项菜单"""
    print("\n" + "="*50)
    print(_(APP_TITLE))
    print("="*50)
    print(_(APP_ENCRYPT_FILE))
    print(_(APP_DECRYPT_FILE)) 
    print(_(APP_EXIT_PROGRAM))
    print("-"*50)


def interactive_mode(app: EncryptDecryptApp) -> None:
    """交互式模式"""
    print(_(APP_WELCOME))
    
    while True:
        print_menu()
        choice = Utils().get_user_choice(_(OPERATION_SELECT), ['1', '2', '3'])
        
        if choice == '1':
            # 加密
            print(_(MENU_FILE_ENCRYPTION))
            path = Utils().get_path_input(_(INPUT_ENCRYPT_PATH))
            if not path:
                continue
            
            # 显示信息
            if ArchiveManager().is_directory(path):
                app.show_directory_info(path)
            else:
                app.show_file_info(path)
            
            # 获取密码
            password = Utils().get_password(_(INPUT_ENCRYPT_PASSWORD))
            
            try:
                # 执行加密
                encrypted_path = app.encrypt_file(path, password)
                print(_(STATUS_ENCRYPT_COMPLETE) + encrypted_path)
            except Exception as e:
                print(_(STATUS_ENCRYPT_FAILED) + str(e))
        
        elif choice == '2':
            # 解密
            print(_(MENU_FILE_DECRYPTION))
            filename = Utils().get_filename_input(_(INPUT_DECRYPT_FILENAME))
            if not filename:
                continue
            
            if not filename.endswith(ENCRYPTED_FILE_EXTENSION):
                print(_(WARNING_DECRYPT_EXTENSION) + ENCRYPTED_FILE_EXTENSION + _(EXTENSION_SUFFIX))
            
            app.show_file_info(filename)
            password = Utils().get_password(_(INPUT_DECRYPT_PASSWORD))
            
            try:
                # 执行解密
                decrypted_path = app.decrypt_file(filename, password)
                print(_(STATUS_DECRYPT_COMPLETE) + decrypted_path)
                
                # 显示解密文件信息
                if os.path.exists(decrypted_path):
                    app.show_file_info(decrypted_path)
                    
            except Exception as e:
                print(_(STATUS_DECRYPT_FAILED) + str(e))
                print(_(REASON_PASSWORD_ERROR))
        
        elif choice == '3':
            print(_(STATUS_GOODBYE))
            break
        
        input(_(STATUS_PRESS_ENTER_CONTINUE))


def main():
    """主函数"""
    # 初始化国际化
    init_locale(os.path.join(os.path.dirname(__file__), 'i18n', 'translations', 'translations_constants.json'))
    
    # 解析命令行参数（先简单解析以获取语言设置）
    import sys
    lang = None
    for i, arg in enumerate(sys.argv):
        if arg == '--lang' and i + 1 < len(sys.argv):
            lang = sys.argv[i + 1]
            break
        elif arg.startswith('--lang='):
            lang = arg.split('=', 1)[1]
            break
    
    # 设置语言
    if lang:
        lang_map = {'en': 'en_US', 'zh': 'zh_CN', 'es': 'es_ES'}
        set_language(lang_map.get(lang, 'zh_CN'))
    
    # 解析命令行参数
    args = parse_arguments()
    
    app = EncryptDecryptApp()
    
    # 如果有命令行参数，使用命令行模式
    if len(sys.argv) > 1 and not (args.lang and len(sys.argv) <= 3):
        # 验证参数
        if args.encrypt and args.decrypt:
            print(_(ERROR_BOTH_ENCRYPT_DECRYPT))
            return 1
        elif not args.encrypt and not args.decrypt:
            print(_(ERROR_NO_ENCRYPT_DECRYPT))
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
            print(_(STATUS_PROGRAM_INTERRUPTED))
            return 0
        except Exception as e:
            print(_(STATUS_PROGRAM_ERROR) + str(e))
            return 1


if __name__ == "__main__":
    sys.exit(main())