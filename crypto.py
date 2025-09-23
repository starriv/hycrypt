#!/usr/bin/env python3
"""
加密解密核心模块
提供 AES-256-CBC 加密和 Argon2id 密钥派生功能
"""

import os
from cryptography.hazmat.primitives.kdf.argon2 import Argon2id
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend

from constants import (
    ARGON2_ITERATIONS, ARGON2_MEMORY_COST, ARGON2_LANES,
    ARGON2_SALT_LENGTH, ARGON2_KEY_LENGTH,
    AES_IV_LENGTH
)


class CryptoManager:
    """加密解密管理器"""
    
    @staticmethod
    def derive_key(password: str, salt: bytes) -> bytes:
        """
        使用 Argon2id 从密码派生密钥
        
        Args:
            password: 用户密码
            salt: 随机盐值
            
        Returns:
            派生的密钥（32字节）
        """
        kdf = Argon2id(
            salt=salt,
            length=ARGON2_KEY_LENGTH,
            iterations=ARGON2_ITERATIONS,
            memory_cost=ARGON2_MEMORY_COST,
            lanes=ARGON2_LANES,
        )
        return kdf.derive(password.encode())
    
    @staticmethod
    def generate_random_bytes(length: int) -> bytes:
        """生成指定长度的随机字节"""
        return os.urandom(length)
    
    @staticmethod
    def encrypt_data(plaintext: bytes, password: str) -> tuple:
        """
        加密数据
        
        Args:
            plaintext: 明文数据
            password: 加密密码
            
        Returns:
            (salt, iv, ciphertext) 元组
        """
        # 生成随机参数
        salt = CryptoManager.generate_random_bytes(ARGON2_SALT_LENGTH)
        iv = CryptoManager.generate_random_bytes(AES_IV_LENGTH)
        
        # 派生密钥
        key = CryptoManager.derive_key(password, salt)
        
        # 创建加密器
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        encryptor = cipher.encryptor()
        
        # PKCS7 填充
        padder = padding.PKCS7(algorithms.AES.block_size).padder()
        padded_data = padder.update(plaintext) + padder.finalize()
        
        # 加密
        ciphertext = encryptor.update(padded_data) + encryptor.finalize()
        
        return salt, iv, ciphertext
    
    @staticmethod
    def decrypt_data(salt: bytes, iv: bytes, ciphertext: bytes, password: str) -> bytes:
        """
        解密数据
        
        Args:
            salt: 盐值
            iv: 初始化向量
            ciphertext: 密文
            password: 解密密码
            
        Returns:
            解密后的明文
            
        Raises:
            Exception: 解密失败时抛出异常
        """
        # 派生密钥
        key = CryptoManager.derive_key(password, salt)
        
        # 创建解密器
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()
        
        # 解密
        decrypted_padded_data = decryptor.update(ciphertext) + decryptor.finalize()
        
        # 去除填充
        unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
        plaintext = unpadder.update(decrypted_padded_data) + unpadder.finalize()
        
        return plaintext
    
    @staticmethod
    def encrypt_file_data(file_path: str, password: str) -> bytes:
        """
        读取文件并加密
        
        Args:
            file_path: 要加密的文件路径
            password: 加密密码
            
        Returns:
            加密后的完整数据（盐+IV+密文）
        """
        # 读取文件内容
        with open(file_path, 'rb') as f:
            plaintext = f.read()
        
        # 加密数据
        salt, iv, ciphertext = CryptoManager.encrypt_data(plaintext, password)
        
        # 组合数据：盐 + IV + 密文
        return salt + iv + ciphertext
    
    @staticmethod
    def decrypt_file_data(encrypted_data: bytes, password: str) -> bytes:
        """
        解密文件数据
        
        Args:
            encrypted_data: 加密的数据
            password: 解密密码
            
        Returns:
            解密后的明文数据
            
        Raises:
            Exception: 解密失败时抛出异常
        """
        # 提取盐、IV 和密文
        salt = encrypted_data[:ARGON2_SALT_LENGTH]
        iv = encrypted_data[ARGON2_SALT_LENGTH:ARGON2_SALT_LENGTH + AES_IV_LENGTH]
        ciphertext = encrypted_data[ARGON2_SALT_LENGTH + AES_IV_LENGTH:]
        
        # 解密数据
        return CryptoManager.decrypt_data(salt, iv, ciphertext, password)