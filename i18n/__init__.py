#!/usr/bin/env python3
"""
hycrypt-py 国际化统一入口模块
提供简洁的国际化接口，隐藏底层实现细节
"""

import os
import sys

# 将 locale 目录添加到 Python 路径
locale_dir = os.path.dirname(os.path.abspath(__file__))
if locale_dir not in sys.path:
    sys.path.insert(0, locale_dir)

# 从 core 模块导入主要功能
from core.i18n_constants import (
    # 翻译函数
    _,
    init_i18n,
    set_language,
    get_current_language,
    get_available_languages,
    
    # 所有翻译常量
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

# 设置默认翻译文件路径
def init_locale(translations_file: str = None):
    """
    初始化国际化系统
    
    Args:
        translations_file: 翻译文件路径，如果为None则使用默认路径
    """
    if translations_file is None:
        translations_file = os.path.join(locale_dir, 'translations', 'translations_constants.json')
    
    # 确保文件存在
    if not os.path.exists(translations_file):
        print(f"Warning: Translations file {translations_file} not found")
    
    return init_i18n(translations_file)

# 工具函数
def add_language(code: str, name: str):
    """添加新语言"""
    from tools.extract_translation_constants import add_language_to_constants_translations
    translations_file = os.path.join(locale_dir, 'translations', 'translations_constants.json')
    return add_language_to_constants_translations(code, name, translations_file)

def validate_translations():
    """验证翻译完整性"""
    from tools.extract_translation_constants import validate_constants_in_translations
    translations_file = os.path.join(locale_dir, 'translations', 'translations_constants.json')
    return validate_constants_in_translations(translations_file)

def get_language_name(code: str) -> str:
    """获取语言显示名称"""
    names = {
        'en_US': 'English',
        'zh_CN': '简体中文',
        'es_ES': 'Español'
    }
    return names.get(code, code)

# 注意：不再自动初始化，由调用程序负责初始化
# init_locale()  # 由主程序调用