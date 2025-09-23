#!/usr/bin/env python3
"""
翻译常量提取工具
从源代码中提取所有翻译常量键
支持常量系统和JSON翻译文件
"""

import os
import re
import json
from typing import Set, Dict, List


def extract_constants_from_i18n_file(filepath: str = None) -> Set[str]:
    """
    从 i18n_constants.py 文件中提取所有常量定义的值
    
    Args:
        filepath: i18n_constants.py 文件路径，如果为None则使用默认路径
        
    Returns:
        常量值集合
    """
    constants = set()
    
    if filepath is None:
        # 使用默认路径
        tool_dir = os.path.dirname(os.path.abspath(__file__))
        filepath = os.path.join(tool_dir, '..', 'core', 'i18n_constants.py')
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 提取常量定义 (CONSTANT_NAME = "value")
        pattern = r'^[A-Z_][A-Z0-9_]*\s*=\s*["\']([^"\']+)["\']'
        matches = re.findall(pattern, content, re.MULTILINE)
        constants.update(matches)
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
    
    return constants


def extract_translation_constants_from_file(filepath: str) -> Set[str]:
    """
    从 Python 文件中提取翻译常量键的值
    
    Args:
        filepath: Python 文件路径
        
    Returns:
        翻译常量值集合
    """
    keys = set()
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 提取 _(CONSTANT) 模式，然后获取常量的值
        pattern = r'_\(([A-Z_][A-Z0-9_]*)\)'
        constant_names = re.findall(pattern, content)
        
        # 从 i18n_constants.py 获取常量的实际值
        if constant_names and os.path.exists('i18n_constants.py'):
            with open('i18n_constants.py', 'r', encoding='utf-8') as f:
                i18n_content = f.read()
            
            for const_name in constant_names:
                # 在 i18n_constants.py 中查找该常量的值
                const_pattern = rf'^{const_name}\s*=\s*["\']([^"\']+)["\']'
                const_matches = re.findall(const_pattern, i18n_content, re.MULTILINE)
                if const_matches:
                    keys.update(const_matches)
        
        # 提取 _(CONSTANT) + "变量" + _(CONSTANT) 模式
        pattern = r'_\(([A-Z_][A-Z0-9_]*)\)\s*\+'
        constant_names = re.findall(pattern, content)
        if constant_names and os.path.exists('i18n_constants.py'):
            with open('i18n_constants.py', 'r', encoding='utf-8') as f:
                i18n_content = f.read()
            
            for const_name in constant_names:
                const_pattern = rf'^{const_name}\s*=\s*["\']([^"\']+)["\']'
                const_matches = re.findall(const_pattern, i18n_content, re.MULTILINE)
                if const_matches:
                    keys.update(const_matches)
        
        # 提取多行翻译模式中的常量
        pattern = r'_\(([A-Z_][A-Z0-9_]*)\)\s*\+\s*[^_]+\+\s*_\(([A-Z_][A-Z0-9_]*)\)'
        constant_pairs = re.findall(pattern, content)
        if constant_pairs and os.path.exists('i18n_constants.py'):
            with open('i18n_constants.py', 'r', encoding='utf-8') as f:
                i18n_content = f.read()
            
            for const1, const2 in constant_pairs:
                for const_name in [const1, const2]:
                    const_pattern = rf'^{const_name}\s*=\s*["\']([^"\']+)["\']'
                    const_matches = re.findall(const_pattern, i18n_content, re.MULTILINE)
                    if const_matches:
                        keys.update(const_matches)
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
    
    return keys


def extract_all_translation_constants(directory: str = '.') -> Set[str]:
    """
    从目录中提取所有翻译常量
    
    Args:
        directory: 要扫描的目录
        
    Returns:
        所有翻译常量的集合
    """
    all_constants = set()
    
    # 扫描 Python 文件
    for root, dirs, files in os.walk(directory):
        # 跳过测试目录和隐藏目录
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['__pycache__', '__demo__']]
        
        for file in files:
            if file.endswith('.py') and not file.startswith('test_') and file != 'extract_translation_constants.py':
                filepath = os.path.join(root, file)
                
                # 如果是 i18n_constants.py，提取常量定义
                if file == 'i18n_constants.py':
                    constants = extract_constants_from_i18n_file(filepath)
                    all_constants.update(constants)
                else:
                    # 其他文件提取常量使用
                    constants = extract_translation_constants_from_file(filepath)
                    all_constants.update(constants)
    
    return all_constants


def validate_constants_in_translations(translations_file: str = None) -> None:
    """
    验证翻译文件中的常量完整性
    
    Args:
        translations_file: 翻译文件路径
    """
    if translations_file is None:
        # 使用相对于工具文件的默认路径
        tool_dir = os.path.dirname(os.path.abspath(__file__))
        translations_file = os.path.join(tool_dir, '..', 'translations', 'translations_constants.json')
        translations_file = os.path.abspath(translations_file)  # 转换为绝对路径
    
    if not os.path.exists(translations_file):
        print(f"❌ 翻译文件不存在: {translations_file}")
        return
    
    with open(translations_file, 'r', encoding='utf-8') as f:
        translations = json.load(f)
    
    # 提取所有翻译常量
    all_constants = extract_all_translation_constants()
    
    # 提取 i18n_constants.py 中定义的所有常量
    i18n_constants = extract_constants_from_i18n_file()  # 使用默认路径
    
    print(f"\n🔍 验证翻译文件: {translations_file}")
    print(f"📊 程序中使用的常量数量: {len(all_constants)}")
    print(f"🔧 i18n_constants.py 中定义的常量数量: {len(i18n_constants)}")
    print(f"🌍 翻译文件中的语言数量: {len(translations)}")
    
    # 检查未使用的常量
    unused_constants = i18n_constants - all_constants
    if unused_constants:
        print(f"\n⚠️  未使用的常量 ({len(unused_constants)}):")
        for const in sorted(list(unused_constants))[:10]:
            print(f"   - {const}")
        if len(unused_constants) > 10:
            print(f"   ... 还有 {len(unused_constants) - 10} 个")
    
    # 检查未定义的常量
    undefined_constants = all_constants - i18n_constants
    if undefined_constants:
        print(f"\n❌ 未定义的常量 ({len(undefined_constants)}):")
        for const in sorted(list(undefined_constants))[:10]:
            print(f"   - {const}")
        if len(undefined_constants) > 10:
            print(f"   ... 还有 {len(undefined_constants) - 10} 个")
    
    for lang_code, lang_translations in translations.items():
        missing_constants = i18n_constants - set(lang_translations.keys())
        extra_constants = set(lang_translations.keys()) - i18n_constants
        untranslated = [k for k, v in lang_translations.items() if v.startswith('[TRANSLATE]')]
        
        print(f"\n📖 {lang_code}:")
        print(f"   ✅ 已翻译: {len(lang_translations) - len(untranslated)}/{len(i18n_constants)}")
        
        if missing_constants:
            print(f"   ❌ 缺失常量: {len(missing_constants)} 个")
            for const in sorted(list(missing_constants))[:5]:
                print(f"      - {const}")
            if len(missing_constants) > 5:
                print(f"      ... 还有 {len(missing_constants) - 5} 个")
        
        if extra_constants:
            print(f"   ⚠️  多余常量: {len(extra_constants)} 个")
        
        if untranslated:
            print(f"   📝 待翻译: {len(untranslated)} 个")
            for const in untranslated[:3]:
                print(f"      - {const}")
            if len(untranslated) > 3:
                print(f"      ... 还有 {len(untranslated) - 3} 个")


def create_constants_template() -> Dict[str, str]:
    """
    创建新的常量模板
    
    Returns:
        常量模板字典
    """
    template = {}
    
    # 提取所有程序中使用的常量
    all_constants = extract_all_translation_constants()
    
    print(f"\n🔧 创建常量模板")
    print(f"📊 找到 {len(all_constants)} 个程序中使用的常量\n")
    
    for const in sorted(list(all_constants)):
        # 提供占位符描述
        template[const] = f"[CONSTANT] {const.lower().replace('_', ' ')}"
        print(f"  {const}")
    
    return template


def generate_i18n_constants_file() -> None:
    """
    生成新的 i18n_constants.py 文件模板
    """
    constants = create_constants_template()
    
    output_file = 'i18n_constants_new.py'
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("#!/usr/bin/env python3\n")
        f.write('"""\n')
        f.write('国际化常量定义\n')
        f.write('本文件由 extract_translation_constants.py 自动生成\n')
        f.write('"""\n\n')
        
        for const_name, description in constants.items():
            f.write(f"{const_name} = \"{description}\"\n")
    
    print(f"\n✅ 已生成新的常量定义文件: {output_file}")
    print(f"🔧 请检查并完善常量定义，然后替换原文件")


def add_language_to_constants_translations(new_language_code: str, new_language_name: str, 
                                         translations_file: str = 'translations_constants.json') -> None:
    """
    添加新语言到常量翻译文件
    
    Args:
        new_language_code: 新语言代码 (如: 'es_ES', 'fr_FR')
        new_language_name: 新语言名称 (如: 'Spanish', 'French')
        translations_file: 翻译文件路径
    """
    # 加载现有翻译
    if os.path.exists(translations_file):
        with open(translations_file, 'r', encoding='utf-8') as f:
            translations = json.load(f)
    else:
        translations = {}
    
    # 提取所有定义的常量
    i18n_constants = set()
    if os.path.exists('i18n_constants.py'):
        i18n_constants = extract_constants_from_i18n_file('i18n_constants.py')
    
    # 创建新语言模板
    template = {}
    
    print(f"\n🌍 创建 {new_language_name} 翻译模板")
    print(f"📊 找到 {len(i18n_constants)} 个需要翻译的常量\n")
    
    for const in sorted(list(i18n_constants)):
        # 对于新语言，提供占位符翻译
        template[const] = f"[TRANSLATE] {const.lower().replace('_', ' ')}"
        print(f"  {const}")
    
    # 添加到翻译文件
    translations[new_language_code] = template
    
    # 保存更新后的翻译文件
    with open(translations_file, 'w', encoding='utf-8') as f:
        json.dump(translations, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ 已添加 {new_language_name} 翻译模板到 {translations_file}")
    print(f"📁 语言代码: {new_language_code}")
    print(f"🔧 请编辑翻译文件完成实际翻译")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='翻译常量提取和管理工具')
    parser.add_argument('--add-language', nargs=2, metavar=('CODE', 'NAME'),
                       help='添加新语言 (如: es_ES Spanish)')
    parser.add_argument('--validate', action='store_true',
                       help='验证翻译文件的完整性')
    parser.add_argument('--extract', action='store_true',
                       help='提取所有翻译常量')
    parser.add_argument('--generate-constants', action='store_true',
                       help='生成新的 i18n_constants.py 文件')
    parser.add_argument('--translations-file', default=None,
                       help='翻译文件路径 (默认: hylocale/translations/translations_constants.json)')
    
    args = parser.parse_args()
    
    if args.generate_constants:
        generate_i18n_constants_file()
    elif args.add_language:
        lang_code, lang_name = args.add_language
        add_language_to_constants_translations(lang_code, lang_name, args.translations_file)
    elif args.validate:
        validate_constants_in_translations(args.translations_file)
    elif args.extract:
        constants = extract_all_translation_constants()
        print(f"提取到 {len(constants)} 个翻译常量")
        for const in sorted(list(constants)):
            print(f"  {const}")
    else:
        # 默认显示当前状态
        validate_constants_in_translations(args.translations_file)


if __name__ == '__main__':
    main()