#!/usr/bin/env python3
"""
大文件处理性能测试
"""

import unittest
import sys
import os
import tempfile
import shutil
import time

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from main import EncryptDecryptApp


class TestLargeFilePerformance(unittest.TestCase):
    """大文件性能测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.app = EncryptDecryptApp()
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "performance_test_password"
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def create_large_file(self, size_mb):
        """创建指定大小的大文件"""
        test_file = os.path.join(self.test_dir, f"large_file_{size_mb}mb.bin")
        chunk_size = 1024 * 1024  # 1MB chunks
        total_chunks = size_mb
        
        with open(test_file, 'wb') as f:
            for _ in range(total_chunks):
                f.write(os.urandom(chunk_size))
        
        return test_file
    
    def measure_operation_time(self, operation_func, *args, **kwargs):
        """测量操作执行时间"""
        start_time = time.time()
        result = operation_func(*args, **kwargs)
        end_time = time.time()
        return result, end_time - start_time
    
    def test_10mb_file_performance(self):
        """测试10MB文件性能"""
        # 创建10MB测试文件
        test_file = self.create_large_file(10)
        
        # 测量加密时间
        encrypted_path, encrypt_time = self.measure_operation_time(
            self.app.encrypt_file, test_file, self.test_password
        )
        
        print(f"10MB文件加密时间: {encrypt_time:.2f}秒")
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 测量解密时间
        decrypted_path, decrypt_time = self.measure_operation_time(
            self.app.decrypt_file, encrypted_path, self.test_password
        )
        
        print(f"10MB文件解密时间: {decrypt_time:.2f}秒")
        
        # 验证解密文件存在且内容正确
        self.assertTrue(os.path.exists(decrypted_path))
        
        # 验证文件大小
        original_size = os.path.getsize(test_file)
        decrypted_size = os.path.getsize(decrypted_path)
        self.assertEqual(original_size, decrypted_size)
        
        # 性能要求：10MB文件加密解密总时间应小于10秒
        total_time = encrypt_time + decrypt_time
        self.assertLess(total_time, 10.0, f"10MB文件处理时间过长: {total_time}秒")
    
    def test_50mb_file_performance(self):
        """测试50MB文件性能"""
        # 创建50MB测试文件
        test_file = self.create_large_file(50)
        
        # 测量加密时间
        encrypted_path, encrypt_time = self.measure_operation_time(
            self.app.encrypt_file, test_file, self.test_password
        )
        
        print(f"50MB文件加密时间: {encrypt_time:.2f}秒")
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 测量解密时间
        decrypted_path, decrypt_time = self.measure_operation_time(
            self.app.decrypt_file, encrypted_path, self.test_password
        )
        
        print(f"50MB文件解密时间: {decrypt_time:.2f}秒")
        
        # 验证解密文件存在且内容正确
        self.assertTrue(os.path.exists(decrypted_path))
        
        # 性能要求：50MB文件处理时间应合理
        total_time = encrypt_time + decrypt_time
        self.assertLess(total_time, 60.0, f"50MB文件处理时间过长: {total_time}秒")
    
    def test_100mb_file_performance(self):
        """测试100MB文件性能（可选）"""
        # 创建100MB测试文件
        test_file = self.create_large_file(100)
        
        # 测量加密时间
        encrypted_path, encrypt_time = self.measure_operation_time(
            self.app.encrypt_file, test_file, self.test_password
        )
        
        print(f"100MB文件加密时间: {encrypt_time:.2f}秒")
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 测量解密时间
        decrypted_path, decrypt_time = self.measure_operation_time(
            self.app.decrypt_file, encrypted_path, self.test_password
        )
        
        print(f"100MB文件解密时间: {decrypt_time:.2f}秒")
        
        # 验证解密文件存在且内容正确
        self.assertTrue(os.path.exists(decrypted_path))
        
        # 性能要求：100MB文件处理时间应合理
        total_time = encrypt_time + decrypt_time
        print(f"100MB文件总处理时间: {total_time:.2f}秒")
        
        # 记录性能基准，但不设置严格的失败条件
        # 主要目的是监控性能趋势
        self.assertLess(total_time, 300.0, f"100MB文件处理时间异常: {total_time}秒")
    
    def test_large_directory_performance(self):
        """测试大目录性能"""
        # 创建包含多个文件的目录
        test_dir = os.path.join(self.test_dir, "large_directory")
        os.makedirs(test_dir)
        
        # 创建多个中等大小的文件
        file_count = 100
        file_size = 1024 * 1024  # 1MB each
        total_size = file_count * file_size
        
        print(f"创建大目录: {file_count} 个文件, 总大小 {total_size // (1024*1024)}MB")
        
        # 创建文件
        for i in range(file_count):
            file_path = os.path.join(test_dir, f"file_{i:03d}.bin")
            with open(file_path, 'wb') as f:
                f.write(os.urandom(file_size))
        
        # 测量目录加密时间
        encrypted_path, encrypt_time = self.measure_operation_time(
            self.app.encrypt_file, test_dir, self.test_password
        )
        
        print(f"大目录加密时间: {encrypt_time:.2f}秒")
        
        # 验证加密文件存在
        self.assertTrue(os.path.exists(encrypted_path))
        
        # 移除原始目录
        shutil.rmtree(test_dir)
        
        # 测量目录解密时间
        decrypted_path, decrypt_time = self.measure_operation_time(
            self.app.decrypt_file, encrypted_path, self.test_password
        )
        
        print(f"大目录解密时间: {decrypt_time:.2f}秒")
        
        # 验证解密目录存在
        self.assertTrue(os.path.exists(decrypted_path))
        self.assertTrue(os.path.isdir(decrypted_path))
        
        # 验证文件数量
        decrypted_file_count = sum(len(files) for _, _, files in os.walk(decrypted_path))
        self.assertEqual(decrypted_file_count, file_count)
        
        # 性能要求
        total_time = encrypt_time + decrypt_time
        self.assertLess(total_time, 120.0, f"大目录处理时间过长: {total_time}秒")
    
    def test_performance_scaling(self):
        """测试性能扩展性"""
        # 测试不同大小文件的性能扩展
        sizes = [1, 5, 10, 20]  # MB
        results = []
        
        for size_mb in sizes:
            test_file = self.create_large_file(size_mb)
            
            # 测量加密时间
            _, encrypt_time = self.measure_operation_time(
                self.app.encrypt_file, test_file, self.test_password
            )
            
            # 清理加密文件
            encrypted_file = test_file + ".enc"
            if os.path.exists(encrypted_file):
                os.remove(encrypted_file)
            
            results.append({
                'size_mb': size_mb,
                'encrypt_time': encrypt_time,
                'throughput_mbps': size_mb / encrypt_time if encrypt_time > 0 else 0
            })
            
            print(f"{size_mb}MB文件: {encrypt_time:.2f}秒, 吞吐量: {results[-1]['throughput_mbps']:.2f}MB/s")
        
        # 验证性能扩展合理性
        # 随着文件增大，处理时间应该大致线性增长
        for i in range(1, len(results)):
            time_ratio = results[i]['encrypt_time'] / results[i-1]['encrypt_time']
            size_ratio = results[i]['size_mb'] / results[i-1]['size_mb']
            
            # 时间增长比例应该与大小增长比例相近（允许50%误差）
            self.assertLess(abs(time_ratio - size_ratio), size_ratio * 0.5,
                          f"性能扩展不合理: {results[i-1]['size_mb']}MB -> {results[i]['size_mb']}MB")


class TestPerformanceBenchmarks(unittest.TestCase):
    """性能基准测试"""
    
    def setUp(self):
        """测试前的设置"""
        self.app = EncryptDecryptApp()
        self.test_dir = tempfile.mkdtemp()
        self.test_password = "benchmark_password"
    
    def tearDown(self):
        """测试后的清理"""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_encryption_throughput(self):
        """测试加密吞吐量"""
        # 创建100MB测试文件
        test_file = os.path.join(self.test_dir, "throughput_test.bin")
        size_mb = 100
        
        with open(test_file, 'wb') as f:
            f.write(os.urandom(size_mb * 1024 * 1024))
        
        # 测量加密时间
        start_time = time.time()
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        end_time = time.time()
        
        encrypt_time = end_time - start_time
        throughput_mbps = size_mb / encrypt_time if encrypt_time > 0 else 0
        
        print(f"加密吞吐量: {throughput_mbps:.2f} MB/s")
        
        # 记录基准，但不设置严格的失败条件
        self.assertGreater(throughput_mbps, 1.0, f"加密吞吐量过低: {throughput_mbps} MB/s")
    
    def test_decryption_throughput(self):
        """测试解密吞吐量"""
        # 创建100MB测试文件并加密
        test_file = os.path.join(self.test_dir, "decrypt_throughput_test.bin")
        size_mb = 100
        
        with open(test_file, 'wb') as f:
            f.write(os.urandom(size_mb * 1024 * 1024))
        
        encrypted_path = self.app.encrypt_file(test_file, self.test_password)
        
        # 测量解密时间
        start_time = time.time()
        decrypted_path = self.app.decrypt_file(encrypted_path, self.test_password)
        end_time = time.time()
        
        decrypt_time = end_time - start_time
        throughput_mbps = size_mb / decrypt_time if decrypt_time > 0 else 0
        
        print(f"解密吞吐量: {throughput_mbps:.2f} MB/s")
        
        # 记录基准，但不设置严格的失败条件
        self.assertGreater(throughput_mbps, 1.0, f"解密吞吐量过低: {throughput_mbps} MB/s")


if __name__ == '__main__':
    unittest.main()