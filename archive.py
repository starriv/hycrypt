#!/usr/bin/env python3
"""
目录压缩解压模块
提供目录的 ZIP 压缩和解压功能
"""

import os
import zipfile
from datetime import datetime

from constants import (
    DIRECTORY_ARCHIVE_FORMAT, DIRECTORY_ARCHIVE_SUFFIX,
    DIRECTORY_ARCHIVE_DATE_FORMAT, DIRECTORY_ARCHIVE_NAME_PATTERN
)


class ArchiveManager:
    """目录压缩解压管理器"""
    
    @staticmethod
    def is_directory(path: str) -> bool:
        """检查路径是否为目录"""
        return os.path.isdir(path)
    
    @staticmethod
    def generate_archive_name(directory_path: str) -> str:
        """
        生成压缩文件名称
        
        Args:
            directory_path: 目录路径
            
        Returns:
            压缩文件完整路径
        """
        dirname = os.path.basename(directory_path)
        date_str = datetime.now().strftime(DIRECTORY_ARCHIVE_DATE_FORMAT)
        archive_name = DIRECTORY_ARCHIVE_NAME_PATTERN.format(
            date=date_str,
            dirname=dirname,
            suffix=DIRECTORY_ARCHIVE_SUFFIX
        )
        
        # 压缩文件放在原始目录同级位置
        parent_dir = os.path.dirname(directory_path)
        if not parent_dir:
            parent_dir = '.'
        return os.path.join(parent_dir, archive_name)
    
    @staticmethod
    def create_directory_archive(directory_path: str) -> str:
        """
        创建目录压缩文件
        
        Args:
            directory_path: 要压缩的目录路径
            
        Returns:
            压缩文件路径
            
        Raises:
            Exception: 压缩失败时抛出异常
        """
        # 检查目录是否存在
        if not os.path.exists(directory_path):
            raise FileNotFoundError(f"目录不存在: {directory_path}")
        
        if not os.path.isdir(directory_path):
            raise NotADirectoryError(f"路径不是目录: {directory_path}")
        
        archive_path = ArchiveManager.generate_archive_name(directory_path)
        
        try:
            with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                # 获取目录的基本名称，用于保持目录结构
                base_dir_name = os.path.basename(directory_path)
                
                for root, dirs, files in os.walk(directory_path):
                    for file in files:
                        file_path = os.path.join(root, file)
                        # 保持相对目录结构，包含根目录名称
                        arcname = os.path.join(base_dir_name, os.path.relpath(file_path, directory_path))
                        zipf.write(file_path, arcname)
            return archive_path
        except Exception as e:
            # 清理失败的压缩文件
            if os.path.exists(archive_path):
                os.remove(archive_path)
            raise Exception(f"创建目录压缩文件失败: {e}")
    
    @staticmethod
    def extract_directory_archive(archive_path: str, extract_to: str = None) -> str:
        """
        解压目录文件
        
        Args:
            archive_path: 压缩文件路径
            extract_to: 解压目标目录（可选，默认为压缩文件所在目录）
            
        Returns:
            解压后的目录路径
            
        Raises:
            Exception: 解压失败时抛出异常
        """
        if extract_to is None:
            # 如果没有指定解压目录，解压到压缩文件所在目录
            extract_to = os.path.dirname(archive_path)
        
        try:
            with zipfile.ZipFile(archive_path, 'r') as zipf:
                # 获取压缩文件中的第一个条目来确定原始目录名
                first_member = zipf.namelist()[0]
                original_dirname = first_member.split('/')[0] if '/' in first_member else os.path.splitext(os.path.basename(archive_path))[0]
                
                # 解压文件
                zipf.extractall(extract_to)
                
                # 返回解压后的目录路径
                extracted_path = os.path.join(extract_to, original_dirname)
                return extracted_path if os.path.exists(extracted_path) else extract_to
        except Exception as e:
            raise Exception(f"解压目录文件失败: {e}")
    
    @staticmethod
    def get_directory_info(directory_path: str) -> dict:
        """
        获取目录信息
        
        Args:
            directory_path: 目录路径
            
        Returns:
            包含文件数量和总大小的字典
        """
        file_count = 0
        total_size = 0
        
        for dirpath, dirnames, filenames in os.walk(directory_path):
            file_count += len(filenames)
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                try:
                    total_size += os.path.getsize(file_path)
                except OSError:
                    # 跳过无法访问的文件
                    continue
        
        return {
            'file_count': file_count,
            'total_size': total_size
        }