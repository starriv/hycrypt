# hylocale - hycrypt-py Internationalization System

## 概述

`hylocale` 是 hycrypt-py 的国际化系统，采用常量模式提供多语言支持。

## 目录结构

```
hylocale/
├── __init__.py              # 统一入口模块
├── core/
│   └── i18n_constants.py    # 翻译常量定义
├── translations/
│   └── translations_constants.json  # 翻译文件
└── tools/
    └── extract_translation_constants.py  # 翻译管理工具
```

## 使用方法

### 基本使用

```python
from hylocale import _, init_locale, set_language, APP_TITLE, APP_WELCOME

# 初始化国际化系统
init_locale()

# 设置语言
set_language('en_US')

# 使用翻译
print(_(APP_WELCOME))
```

### 在主程序中使用

```python
from hylocale import (
    _, init_locale, set_language,
    APP_TITLE, APP_WELCOME, APP_ENCRYPT_FILE, APP_DECRYPT_FILE
)

# 初始化并设置语言
init_locale()
set_language('zh_CN')

# 使用常量翻译
print(_(APP_TITLE))
print(_(APP_WELCOME))
```

## 支持的常量

主要常量分类：

- **应用常量**: `APP_TITLE`, `APP_WELCOME`, `APP_ENCRYPT_FILE`, `APP_DECRYPT_FILE`
- **输入提示**: `INPUT_ENCRYPT_PATH`, `INPUT_ENCRYPT_PASSWORD`, `INPUT_DECRYPT_FILENAME`
- **状态消息**: `STATUS_ENCRYPT_COMPLETE`, `STATUS_DECRYPT_COMPLETE`, `STATUS_ENCRYPT_FAILED`
- **错误消息**: `ERROR_PASSWORD_EMPTY`, `ERROR_PATH_NOT_EXIST`, `ERROR_FILE_NOT_EXIST`
- **成功消息**: `SUCCESS_ENCRYPT_COMPLETE`, `SUCCESS_DECRYPT_COMPLETE`
- **文件信息**: `FILE_INFO_FILE`, `FILE_INFO_SIZE`, `FILE_INFO_ALGORITHM`
- **警告消息**: `WARNING_PASSWORD_LENGTH`, `WARNING_PASSWORD_STRENGTH`
- **测试相关**: `TEST_RUNNER`, `ALL_TESTS_PASSED`, `SOME_TESTS_FAILED`

## 语言支持

- `en_US`: English (完整翻译)
- `zh_CN`: 简体中文 (完整翻译)  
- `es_ES`: Español (模板，需要翻译)

## 工具使用

### 验证翻译完整性

```bash
python3 hylocale/tools/extract_translation_constants.py --validate
```

### 添加新语言

```bash
python3 hylocale/tools/extract_translation_constants.py --add-language fr_FR French
```

### 提取所有翻译常量

```bash
python3 hylocale/tools/extract_translation_constants.py --extract
```

## 工作流程

### 1. 添加新的翻译文本

1. 在 `hylocale/core/i18n_constants.py` 中添加新的常量定义
2. 在代码中使用 `_(CONSTANT_NAME)` 的方式引用
3. 运行验证工具检查完整性

### 2. 添加新语言

1. 使用工具添加新语言模板
2. 编辑 `hylocale/translations/translations_constants.json` 完成翻译
3. 测试新语言支持

### 3. 翻译文件格式

翻译文件使用 JSON 格式，结构如下：

```json
{
  "en_US": {
    "app_title": "hycrypt-py File Encryption/Decryption Tool",
    "app_welcome": "Welcome to hycrypt-py!",
    ...
  },
  "zh_CN": {
    "app_title": "hycrypt-py 文件加密解密工具",
    "app_welcome": "欢迎使用 hycrypt-py！",
    ...
  }
}
```

## 最佳实践

1. **使用常量**: 始终使用预定义的常量，避免硬编码字符串
2. **保持一致性**: 遵循现有的命名约定和分类
3. **及时更新**: 添加新功能时同步更新翻译
4. **验证完整性**: 定期运行验证工具确保翻译完整性
5. **测试多语言**: 在不同语言环境下测试应用

## 向后兼容

系统保持对中文文本键的向后兼容性，但建议使用新的常量模式以获得更好的维护性。

## 性能特点

- **O(1) 查找**: 内存中的翻译查找
- **延迟加载**: 翻译文件按需加载
- **缓存机制**: 翻译结果缓存以提高性能

## 故障排除

### 翻译文件未找到
确保翻译文件位于 `hylocale/translations/translations_constants.json`

### 常量未定义
检查常量是否在 `hylocale/core/i18n_constants.py` 中正确定义

### 语言切换无效
确保在程序初始化后调用 `set_language()` 函数

## 维护建议

1. 定期清理未使用的常量
2. 保持翻译文件的同步更新
3. 使用版本控制管理翻译变更
4. 建立翻译审查流程