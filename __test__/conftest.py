"""
pytest 配置文件
提供测试固件和全局配置
"""

import pytest
import tempfile
import shutil
import os
import sys

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


@pytest.fixture
def temp_dir():
    """提供临时目录固件"""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir)


@pytest.fixture
def sample_text_file(temp_dir):
    """提供样例文本文件"""
    file_path = os.path.join(temp_dir, "sample.txt")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write("This is sample text content for testing.\n")
    return file_path


@pytest.fixture
def sample_binary_file(temp_dir):
    """提供样例二进制文件"""
    file_path = os.path.join(temp_dir, "sample.bin")
    with open(file_path, 'wb') as f:
        f.write(b"\x00\x01\x02\x03\x04\x05" * 100)
    return file_path


@pytest.fixture
def sample_directory(temp_dir):
    """提供样例目录结构"""
    root_dir = os.path.join(temp_dir, "sample_project")
    os.makedirs(root_dir)
    
    # 创建子目录
    docs_dir = os.path.join(root_dir, "docs")
    src_dir = os.path.join(root_dir, "src")
    os.makedirs(docs_dir)
    os.makedirs(src_dir)
    
    # 创建文件
    files = [
        (os.path.join(root_dir, "readme.txt"), "Project readme"),
        (os.path.join(docs_dir, "manual.txt"), "User manual"),
        (os.path.join(src_dir, "main.py"), "def main(): pass"),
        (os.path.join(src_dir, "utils.py"), "def helper(): pass")
    ]
    
    for file_path, content in files:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
    
    return root_dir


@pytest.fixture
def test_password():
    """提供测试用密码"""
    return "test_password_123"


@pytest.fixture
def encrypt_decrypt_app():
    """提供加密解密应用实例"""
    from main import EncryptDecryptApp
    return EncryptDecryptApp()


@pytest.fixture(scope="session")
def test_constants():
    """提供测试用常量"""
    from constants import ENCRYPTED_FILE_EXTENSION, DEMO_DIR
    return {
        'encrypted_extension': ENCRYPTED_FILE_EXTENSION,
        'demo_dir': DEMO_DIR
    }