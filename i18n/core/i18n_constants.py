#!/usr/bin/env python3
"""
国际化常量系统
提供英文常量键和向后兼容的中文键
"""

import json
import os
import locale
from typing import Dict, Optional, Union

# 翻译常量定义
# 程序标题和欢迎信息
APP_TITLE = "app_title"
APP_WELCOME = "app_welcome"
APP_ENCRYPT_FILE = "app_encrypt_file"
APP_DECRYPT_FILE = "app_decrypt_file"
APP_EXIT_PROGRAM = "app_exit_program"

# 操作菜单
MENU_FILE_ENCRYPTION = "menu_file_encryption"
MENU_FILE_DECRYPTION = "menu_file_decryption"

# 输入提示
INPUT_ENCRYPT_PATH = "input_encrypt_path"
INPUT_ENCRYPT_PASSWORD = "input_encrypt_password"
INPUT_DECRYPT_FILENAME = "input_decrypt_filename"
INPUT_DECRYPT_PASSWORD = "input_decrypt_password"
INPUT_FILENAME = "input_filename"
INPUT_PATH = "input_path"
INPUT_PASSWORD = "input_password"
INPUT_PASSWORD_CONFIRM = "input_password_confirm"
INPUT_CHOICE = "input_choice"

# 状态消息
STATUS_ENCRYPT_COMPLETE = "status_encrypt_complete"
STATUS_DECRYPT_COMPLETE = "status_decrypt_complete"
STATUS_ENCRYPT_FAILED = "status_encrypt_failed"
STATUS_DECRYPT_FAILED = "status_decrypt_failed"
STATUS_PROGRAM_ERROR = "status_program_error"
STATUS_PRESS_ENTER_CONTINUE = "status_press_enter_continue"
STATUS_GOODBYE = "status_goodbye"
STATUS_PROGRAM_INTERRUPTED = "status_program_interrupted"

# 可能原因
REASON_PASSWORD_ERROR = "reason_password_error"

# 命令行参数
ARG_DESCRIPTION = "arg_description"
ARG_ENCRYPT_PATH = "arg_encrypt_path"
ARG_DECRYPT_PATH = "arg_decrypt_path"
ARG_PASSWORD_HELP = "arg_password_help"
ARG_OUTPUT_HELP = "arg_output_help"
ARG_QUIET_HELP = "arg_quiet_help"
ARG_VERBOSE_HELP = "arg_verbose_help"
ARG_LANGUAGE_HELP = "arg_language_help"

# 错误消息
ERROR_BOTH_ENCRYPT_DECRYPT = "error_both_encrypt_decrypt"
ERROR_NO_ENCRYPT_DECRYPT = "error_no_encrypt_decrypt"
ERROR_PASSWORD_EMPTY = "error_password_empty"
ERROR_PATH_NOT_EXIST = "error_path_not_exist"
ERROR_FILE_NOT_EXIST = "error_file_not_exist"
ERROR_OPERATION_FAILED = "error_operation_failed"
ERROR_FILENAME_EMPTY = "error_filename_empty"
ERROR_PATH_EMPTY = "error_path_empty"
ERROR_INVALID_CHOICE = "error_invalid_choice"

# 成功消息
SUCCESS_ENCRYPT_COMPLETE = "success_encrypt_complete"
SUCCESS_DECRYPT_COMPLETE = "success_decrypt_complete"
SUCCESS_PASSWORD_CONFIRMED = "success_password_confirmed"
SUCCESS_DIR_COMPRESSED = "success_dir_compressed"
SUCCESS_ARCHIVE_EXTRACTED = "success_archive_extracted"
SUCCESS_TEMP_CLEANED = "success_temp_cleaned"

# 文件操作消息
FILE_DETECTED_DIR_COMPRESSING = "file_detected_dir_compressing"
FILE_DETECTED_ARCHIVE_EXTRACTING = "file_detected_archive_extracting"
FILE_ARCHIVE_EXTRACT_FAILED = "file_archive_extract_failed"
FILE_ARCHIVE_EXTRACT_KEEP = "file_archive_extract_keep"
FILE_TEMP_CLEANED = "file_temp_cleaned"

# 文件信息
FILE_INFO_FILE = "file_info_file"
FILE_INFO_SIZE = "file_info_size"
FILE_INFO_DIR = "file_info_dir"
FILE_INFO_COUNT = "file_info_count"
FILE_INFO_TOTAL_SIZE = "file_info_total_size"
FILE_INFO_ALGORITHM = "file_info_algorithm"

# 警告消息
WARNING_PASSWORD_LENGTH = "warning_password_length"
WARNING_PASSWORD_STRENGTH = "warning_password_strength"
WARNING_DECRYPT_EXTENSION = "warning_decrypt_extension"
WARNING_ARCHIVE_EXTRACT_FAILED = "warning_archive_extract_failed"

# 大小格式化
SIZE_BYTES = "size_bytes"
SIZE_KB = "size_kb"
SIZE_MB = "size_mb"
SIZE_GB = "size_gb"

# 使用示例
USAGE_EXAMPLES = "usage_examples"
USAGE_INTERACTIVE = "usage_interactive"
USAGE_ENCRYPT_CLI = "usage_encrypt_cli"
USAGE_DECRYPT_CLI = "usage_decrypt_cli"
USAGE_OUTPUT_FILENAME = "usage_output_filename"

# 语言选择
LANGUAGE_SELECT = "language_select"
LANGUAGE_EN = "language_en"
LANGUAGE_ZH = "language_zh"
LANGUAGE_ES = "language_es"

# 操作选择
OPERATION_SELECT = "operation_select"

# 扩展名相关
EXTENSION_NOTICE = "extension_notice"
EXTENSION_SUFFIX = "extension_suffix"

# 测试相关
TEST_COVERAGE = "test_coverage"
TEST_RUNNER = "test_runner"
START_TESTS = "start_tests"
ALL_TESTS_PASSED = "all_tests_passed"
SOME_TESTS_FAILED = "some_tests_failed"
RUN_ALL_TESTS = "run_all_tests"
RUN_UNIT_TESTS = "run_unit_tests"
RUN_INTEGRATION_TESTS = "run_integration_tests"
RUN_PERFORMANCE_TESTS = "run_performance_tests"
RUN_SPECIFIC_TEST = "run_specific_test"
RUN_LEGACY_TESTS = "run_legacy_tests"
SHOW_TEST_COVERAGE = "show_test_coverage"
DETAILED_OUTPUT = "detailed_output"
ERROR_TEST_FILE_NOT_FOUND = "error_test_file_not_found"
ERROR_NO_TEST_FILES = "error_no_test_files"
ERROR_PYTEST_NOT_FOUND = "error_pytest_not_found"
ERROR_TEST_RUN_FAILED = "error_test_run_failed"
RUN_TEST_COMMAND = "run_test_command"
RUN_TEST_FILE = "run_test_file"
SUCCESS_TEST_PASSED = "success_test_passed"
ERROR_TEST_FAILED = "error_test_failed"
ERROR_RUN_TEST_ERROR = "error_run_test_error"
RUN_LEGACY_TEST = "run_legacy_test"
OUTPUT_LABEL = "output_label"
ERROR_LABEL = "error_label"
TEST_RESULTS = "test_results"
RUN_LEGACY_FILES = "run_legacy_files"
TOTAL_TEST_FILES = "total_test_files"
TEST_SUMMARY = "test_summary"
UNIT_TEST_COUNT = "unit_test_count"
INTEGRATION_TEST_COUNT = "integration_test_count"
PERFORMANCE_TEST_COUNT = "performance_test_count"

# 反向映射：中文文本 -> 常量键（用于迁移工具）
CHINESE_TO_CONSTANT = {
    # 程序标题和欢迎信息
    "           hycrypt-py 文件加密解密工具": APP_TITLE,
    "🔐 欢迎使用 hycrypt-py 文件加密解密工具！": APP_WELCOME,
    "1. 加密文件": APP_ENCRYPT_FILE,
    "2. 解密文件": APP_DECRYPT_FILE,
    "3. 退出程序": APP_EXIT_PROGRAM,
    
    # 操作菜单
    "\n--- 文件/目录加密 ---": MENU_FILE_ENCRYPTION,
    "\n--- 文件解密 ---": MENU_FILE_DECRYPTION,
    
    # 输入提示
    "请输入要加密的文件或目录路径: ": INPUT_ENCRYPT_PATH,
    "请输入加密密码: ": INPUT_ENCRYPT_PASSWORD,
    "请输入要解密的文件名 (.enc): ": INPUT_DECRYPT_FILENAME,
    "请输入解密密码: ": INPUT_DECRYPT_PASSWORD,
    "请输入文件名: ": INPUT_FILENAME,
    "请输入路径: ": INPUT_PATH,
    "请输入密码: ": INPUT_PASSWORD,
    "请再次输入密码确认: ": INPUT_PASSWORD_CONFIRM,
    "请选择操作": INPUT_CHOICE,
    
    # 状态消息
    "\n✅ 加密完成！加密文件: ": STATUS_ENCRYPT_COMPLETE,
    "\n✅ 解密完成！解密文件: ": STATUS_DECRYPT_COMPLETE,
    "\n❌ 加密失败: ": STATUS_ENCRYPT_FAILED,
    "\n❌ 解密失败: ": STATUS_DECRYPT_FAILED,
    "\n❌ 程序发生错误: ": STATUS_PROGRAM_ERROR,
    "\n按回车键继续...": STATUS_PRESS_ENTER_CONTINUE,
    "\n👋 感谢使用，再见！": STATUS_GOODBYE,
    "\n\n👋 程序被用户中断，再见！": STATUS_PROGRAM_INTERRUPTED,
    
    # 可能原因
    "可能原因: 密码错误或文件损坏": REASON_PASSWORD_ERROR,
    
    # 命令行参数
    "hycrypt-py - 文件加密解密工具，支持AES-256-Argon2id加密": ARG_DESCRIPTION,
    "要加密的文件路径": ARG_ENCRYPT_PATH,
    "要解密的文件路径": ARG_DECRYPT_PATH,
    "加密/解密密码 (如果不提供，将提示输入)": ARG_PASSWORD_HELP,
    "输出文件路径 (可选)": ARG_OUTPUT_HELP,
    "安静模式，减少输出信息": ARG_QUIET_HELP,
    "详细模式，显示更多信息": ARG_VERBOSE_HELP,
    "选择语言 (选择语言: en=英文, zh=中文, es=西班牙文)": ARG_LANGUAGE_HELP,
    
    # 错误消息
    "❌ 不能同时指定加密和解密": ERROR_BOTH_ENCRYPT_DECRYPT,
    "❌ 请指定 -e (加密) 或 -d (解密)": ERROR_NO_ENCRYPT_DECRYPT,
    "❌ 密码不能为空": ERROR_PASSWORD_EMPTY,
    "❌ 路径 '": ERROR_PATH_NOT_EXIST,
    "❌ 文件 '": ERROR_FILE_NOT_EXIST,
    "❌ 操作失败: ": ERROR_OPERATION_FAILED,
    "❌ 文件名不能为空": ERROR_FILENAME_EMPTY,
    "❌ 路径不能为空": ERROR_PATH_EMPTY,
    "❌ 无效选择，请输入 ": ERROR_INVALID_CHOICE,
    
    # 成功消息
    "✅ 加密完成: ": SUCCESS_ENCRYPT_COMPLETE,
    "✅ 解密完成: ": SUCCESS_DECRYPT_COMPLETE,
    "✅ 密码确认通过": SUCCESS_PASSWORD_CONFIRMED,
    "✅ 目录压缩完成: ": SUCCESS_DIR_COMPRESSED,
    "✅ 压缩文件解压完成，解压到: ": SUCCESS_ARCHIVE_EXTRACTED,
    "🗑️  临时压缩文件已清理: ": SUCCESS_TEMP_CLEANED,
    
    # 文件操作消息
    "📁 检测到目录，正在压缩: ": FILE_DETECTED_DIR_COMPRESSING,
    "📁 检测到压缩文件，正在解压: ": FILE_DETECTED_ARCHIVE_EXTRACTING,
    "⚠️  压缩文件解压失败: ": FILE_ARCHIVE_EXTRACT_FAILED,
    "💡 解密后的压缩文件保留在: ": FILE_ARCHIVE_EXTRACT_KEEP,
    "🗑️  临时压缩文件已清理: ": FILE_TEMP_CLEANED,
    
    # 文件信息
    "📁 文件: ": FILE_INFO_FILE,
    "📊 大小: ": FILE_INFO_SIZE,
    "📁 目录: ": FILE_INFO_DIR,
    "📊 文件数量: ": FILE_INFO_COUNT,
    "📊 总大小: ": FILE_INFO_TOTAL_SIZE,
    "🔐 算法: AES-256-CBC + Argon2id": FILE_INFO_ALGORITHM,
    
    # 警告消息
    "⚠️  密码长度建议至少6位": WARNING_PASSWORD_LENGTH,
    "⚠️  密码长度建议至少8位以获得更好的安全性": WARNING_PASSWORD_STRENGTH,
    "⚠️  注意: 解密文件通常以 ": WARNING_DECRYPT_EXTENSION,
    "⚠️  压缩文件解压失败: ": WARNING_ARCHIVE_EXTRACT_FAILED,
    
    # 大小格式化
    "{size_bytes} 字节": SIZE_BYTES,
    "{size_bytes/1024:.1f} KB": SIZE_KB,
    "{size_bytes/(1024*1024):.1f} MB": SIZE_MB,
    "{size_bytes/(1024*1024*1024):.1f} GB": SIZE_GB,
    
    # 使用示例
    "使用示例:": USAGE_EXAMPLES,
    "交互式界面": USAGE_INTERACTIVE,
    "命令行加密": USAGE_ENCRYPT_CLI,
    "命令行解密": USAGE_DECRYPT_CLI,
    "指定输出文件名": USAGE_OUTPUT_FILENAME,
    
    # 语言选择
    "选择语言 (选择语言: en=英文, zh=中文, es=西班牙文)": LANGUAGE_SELECT,
    "英文": LANGUAGE_EN,
    "中文": LANGUAGE_ZH,
    "西班牙文": LANGUAGE_ES,
    
    # 操作选择
    "请选择操作": OPERATION_SELECT,
    
    # 扩展名相关
    "⚠️  注意: 解密文件通常以 ": EXTENSION_NOTICE,
    " 为扩展名": EXTENSION_SUFFIX,
    
    # 测试相关
    "显示测试覆盖率": TEST_COVERAGE,
    "测试运行器": TEST_RUNNER,
    "开始运行测试...": START_TESTS,
    "🎉 所有测试通过！": ALL_TESTS_PASSED,
    "⚠️  部分测试失败": SOME_TESTS_FAILED,
    "运行所有测试（包括遗留）": RUN_ALL_TESTS,
    "仅运行单元测试": RUN_UNIT_TESTS,
    "仅运行集成测试": RUN_INTEGRATION_TESTS,
    "仅运行性能测试": RUN_PERFORMANCE_TESTS,
    "运行特定的测试文件": RUN_SPECIFIC_TEST,
    "同时运行遗留测试": RUN_LEGACY_TESTS,
    "显示测试覆盖率": SHOW_TEST_COVERAGE,
    "详细输出": DETAILED_OUTPUT,
    "❌ 未找到测试文件: {specific_file}": ERROR_TEST_FILE_NOT_FOUND,
    "❌ 没有找到测试文件": ERROR_NO_TEST_FILES,
    "❌ 未找到pytest，尝试使用unittest...": ERROR_PYTEST_NOT_FOUND,
    "❌ 测试运行失败: {e}": ERROR_TEST_RUN_FAILED,
    "🧪 运行测试命令: {' '.join(cmd)}": RUN_TEST_COMMAND,
    "\n📄 运行测试文件: {test_file.name}": RUN_TEST_FILE,
    "✅ {test_file.name} 通过": SUCCESS_TEST_PASSED,
    "❌ {test_file.name} 失败": ERROR_TEST_FAILED,
    "❌ 运行 {test_file.name} 时出错: {e}": ERROR_RUN_TEST_ERROR,
    "\n📄 运行遗留测试: {legacy_file}": RUN_LEGACY_TEST,
    "输出:": OUTPUT_LABEL,
    "错误:": ERROR_LABEL,
    "\n📊 测试结果: {total_tests - failed_tests}/{total_tests} 通过": TEST_RESULTS,
    "\n🔄 运行遗留测试文件...": RUN_LEGACY_FILES,
    "\n总计: {total_tests} 个测试文件": TOTAL_TEST_FILES,
    "📊 测试摘要": TEST_SUMMARY,
    "单元测试: {len(unit_tests)} 个文件": UNIT_TEST_COUNT,
    "集成测试: {len(integration_tests)} 个文件": INTEGRATION_TEST_COUNT,
    "性能测试: {len(performance_tests)} 个文件": PERFORMANCE_TEST_COUNT
}


class ConstantsI18nManager:
    """基于常量的国际化管理器"""
    
    def __init__(self, translations_file: str = 'translations_constants.json'):
        """
        初始化国际化管理器
        
        Args:
            translations_file: 翻译文件路径
        """
        self.translations_file = translations_file
        self.translations = {}
        self.current_language = None
        self.fallback_language = 'zh_CN'
        
        # 设置默认语言
        self.set_language(self.detect_system_language())
    
    def detect_system_language(self) -> str:
        """
        检测系统语言
        
        Returns:
            语言代码 (如: 'en_US', 'zh_CN')
        """
        try:
            # 获取系统默认语言
            if hasattr(locale, 'getdefaultlocale'):
                system_locale = locale.getdefaultlocale()[0]
            else:
                # Python 3.11+ 使用 getlocale
                system_locale = locale.getlocale()[0]
                
            if system_locale:
                # 转换为标准格式
                language = system_locale.replace('-', '_')
                # 检查是否支持该语言
                if language in ['zh_CN', 'zh_TW', 'en_US', 'es_ES']:
                    return language
                elif language.startswith('zh'):
                    return 'zh_CN'
                elif language.startswith('en'):
                    return 'en_US'
                elif language.startswith('es'):
                    return 'es_ES'
        except Exception:
            pass
        
        # 默认返回中文
        return 'zh_CN'
    
    def load_translations(self) -> None:
        """加载翻译文件"""
        try:
            if os.path.exists(self.translations_file):
                with open(self.translations_file, 'r', encoding='utf-8') as f:
                    self.translations = json.load(f)
            else:
                print(f"Warning: Translations file {self.translations_file} not found")
                self.translations = {}
        except Exception as e:
            print(f"Error loading translations: {e}")
            self.translations = {}
    
    def set_language(self, language: str) -> bool:
        """
        设置语言
        
        Args:
            language: 语言代码
            
        Returns:
            是否设置成功
        """
        # 先尝试加载翻译文件
        self.load_translations()
        
        if language in self.translations:
            self.current_language = language
            return True
        elif language == 'en' and 'en_US' in self.translations:
            self.current_language = 'en_US'
            return True
        elif language == 'zh' and 'zh_CN' in self.translations:
            self.current_language = 'zh_CN'
            return True
        elif language == 'es' and 'es_ES' in self.translations:
            self.current_language = 'es_ES'
            return True
        else:
            print(f"Language {language} not found, using fallback")
            self.current_language = self.fallback_language
            return False
    
    def get_available_languages(self) -> list:
        """
        获取可用的语言列表
        
        Returns:
            语言代码列表
        """
        return list(self.translations.keys())
    
    def get_language_name(self, language_code: str) -> str:
        """
        获取语言显示名称
        
        Args:
            language_code: 语言代码
            
        Returns:
            语言显示名称
        """
        language_names = {
            'en_US': 'English',
            'zh_CN': '简体中文',
            'es_ES': 'Español'
        }
        return language_names.get(language_code, language_code)
    
    def translate(self, message: str) -> str:
        """
        翻译消息
        
        Args:
            message: 要翻译的消息（可以是常量或原文）
            
        Returns:
            翻译后的消息
        """
        if not message:
            return message
        
        # 如果当前语言有翻译，使用翻译
        if (self.current_language and 
            self.current_language in self.translations and 
            message in self.translations[self.current_language]):
            return self.translations[self.current_language][message]
        
        # 如果回退语言有翻译，使用回退
        if (self.fallback_language in self.translations and 
            message in self.translations[self.fallback_language]):
            return self.translations[self.fallback_language][message]
        
        # 如果启用了常量模式，尝试通过常量值查找
        if message in CHINESE_TO_CONSTANT:
            const_value = CHINESE_TO_CONSTANT[message]
            # 通过常量值在当前语言中查找
            if (self.current_language in self.translations and 
                const_value in self.translations[self.current_language]):
                return self.translations[self.current_language][const_value]
            # 通过常量值在回退语言中查找
            if (self.fallback_language in self.translations and 
                const_value in self.translations[self.fallback_language]):
                return self.translations[self.fallback_language][const_value]
        
        # 否则返回原消息
        return message
    
    def ngettext(self, singular: str, plural: str, n: int) -> str:
        """
        处理复数形式的翻译
        
        Args:
            singular: 单数形式
            plural: 复数形式
            n: 数量
            
        Returns:
            翻译后的消息
        """
        return singular if n == 1 else plural


# 全局国际化管理器实例
i18n = ConstantsI18nManager()


def init_i18n(translations_file: str = 'translations_constants.json') -> ConstantsI18nManager:
    """
    初始化国际化系统
    
    Args:
        translations_file: 翻译文件路径
        
    Returns:
        国际化管理器实例
    """
    global i18n
    i18n = ConstantsI18nManager(translations_file)
    return i18n


def _(message: str) -> str:
    """
    翻译函数快捷方式
    
    Args:
        message: 要翻译的消息
        
    Returns:
        翻译后的消息
    """
    return i18n.translate(message)


def set_language(language: str) -> bool:
    """
    设置当前语言
    
    Args:
        language: 语言代码
        
    Returns:
        是否设置成功
    """
    return i18n.set_language(language)


def get_current_language() -> str:
    """
    获取当前语言
    
    Returns:
        当前语言代码
    """
    return i18n.current_language


def get_available_languages() -> list:
    """
    获取可用语言列表
    
    Returns:
        可用语言代码列表
    """
    return i18n.get_available_languages()


# 向后兼容：也支持直接使用常量作为键
def translate_constant(constant_name: str) -> str:
    """
    使用常量名进行翻译
    
    Args:
        constant_name: 常量名称
        
    Returns:
        翻译后的文本
    """
    if constant_name in CHINESE_TO_CONSTANT:
        return _(CHINESE_TO_CONSTANT[constant_name])
    return _(constant_name)


if __name__ == "__main__":
    # 测试常量系统
    print("翻译常量系统测试:")
    print(f"当前语言: {get_current_language()}")
    print(f"APP_WELCOME: {_(APP_WELCOME)}")
    print(f"FILE_INFO_ALGORITHM: {_(FILE_INFO_ALGORITHM)}")
    
    # 测试中文键映射
    print(f"中文映射测试: {translate_constant('欢迎使用')}")
    
    # 测试语言切换
    set_language('en_US')
    print(f"切换到英文后 - APP_WELCOME: {_(APP_WELCOME)}")
    
    # 测试西班牙语
    set_language('es_ES')
    print(f"西班牙语 - APP_WELCOME: {_(APP_WELCOME)}")