#!/usr/bin/env python3
"""
测试运行器 - 支持新的测试目录结构

使用方法:
    python __test__/run_tests.py                    # 运行所有测试
    python __test__/run_tests.py --unit            # 运行单元测试
    python __test__/run_tests.py --integration     # 运行集成测试
    python __test__/run_tests.py --performance     # 运行性能测试
    python __test__/run_tests.py --file test_crypto.py  # 运行特定文件
    python __test__/run_tests.py --coverage        # 显示测试覆盖率
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path


class TestRunner:
    """测试运行器类"""
    
    def __init__(self):
        self.test_root = Path(__file__).parent
        self.project_root = self.test_root.parent
        self.setup_paths()
    
    def setup_paths(self):
        """设置Python路径"""
        # 添加项目根目录到Python路径
        if str(self.project_root) not in sys.path:
            sys.path.insert(0, str(self.project_root))
    
    def discover_tests(self, test_type=None, specific_file=None):
        """发现测试文件"""
        test_files = []
        
        if specific_file:
            # 运行特定文件
            for test_dir in ['unit', 'integration', 'performance']:
                test_file = self.test_root / test_dir / specific_file
                if test_file.exists():
                    test_files.append(test_file)
                    break
            
            if not test_files:
                print(f"❌ 未找到测试文件: {specific_file}")
                return []
        else:
            # 根据类型发现测试
            test_dirs = []
            
            if test_type == 'unit' or test_type is None:
                test_dirs.append('unit')
            if test_type == 'integration' or test_type is None:
                test_dirs.append('integration')
            if test_type == 'performance' or test_type is None:
                test_dirs.append('performance')
            
            for test_dir in test_dirs:
                test_path = self.test_root / test_dir
                if test_path.exists():
                    # 查找所有 test_*.py 文件
                    for test_file in test_path.glob("test_*.py"):
                        test_files.append(test_file)
        
        return sorted(test_files)
    
    def run_tests_with_pytest(self, test_files, verbose=False, coverage=False):
        """使用pytest运行测试"""
        if not test_files:
            print("❌ 没有找到测试文件")
            return False
        
        cmd = ["python", "-m", "pytest"]
        
        if verbose:
            cmd.extend(["-v", "-s"])
        
        if coverage:
            cmd.extend(["--cov=.", "--cov-report=term-missing"])
        
        # 添加测试文件
        for test_file in test_files:
            cmd.append(str(test_file))
        
        print(f"🧪 运行测试命令: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(cmd, cwd=str(self.project_root), check=True)
            return result.returncode == 0
        except subprocess.CalledProcessError as e:
            print(f"❌ 测试运行失败: {e}")
            return False
        except FileNotFoundError:
            print("❌ 未找到pytest，尝试使用unittest...")
            return self.run_tests_with_unittest(test_files, verbose)
    
    def run_tests_with_unittest(self, test_files, verbose=False):
        """使用unittest运行测试"""
        if not test_files:
            print("❌ 没有找到测试文件")
            return False
        
        success = True
        total_tests = 0
        failed_tests = 0
        
        for test_file in test_files:
            print(f"\n📄 运行测试文件: {test_file.name}")
            
            # 直接运行测试文件
            cmd = ["python", str(test_file)]
            
            try:
                result = subprocess.run(cmd, cwd=str(self.project_root), capture_output=True, text=True)
                
                if result.returncode == 0:
                    # 简单的成功检测
                    print(f"✅ {test_file.name} 通过")
                else:
                    print(f"❌ {test_file.name} 失败")
                    print("输出:", result.stdout)
                    print("错误:", result.stderr)
                    success = False
                    failed_tests += 1
                    
            except Exception as e:
                print(f"❌ 运行 {test_file.name} 时出错: {e}")
                success = False
                failed_tests += 1
        
        print(f"\n📊 测试结果: {total_tests - failed_tests}/{total_tests} 通过")
        return success
    
    def run_legacy_tests(self):
        """运行遗留的测试文件以兼容旧版本"""
        legacy_files = [
            "test_integrated.py",
            "test_refactor.py"
        ]
        
        print("\n🔄 运行遗留测试文件...")
        
        success = True
        for legacy_file in legacy_files:
            legacy_path = self.project_root / legacy_file
            if legacy_path.exists():
                print(f"📄 运行遗留测试: {legacy_file}")
                try:
                    result = subprocess.run(
                        ["python", str(legacy_path)],
                        cwd=str(self.project_root),
                        capture_output=True,
                        text=True
                    )
                    
                    if result.returncode == 0:
                        print(f"✅ {legacy_file} 通过")
                    else:
                        print(f"❌ {legacy_file} 失败")
                        print(result.stdout)
                        print(result.stderr)
                        success = False
                except Exception as e:
                    print(f"❌ 运行 {legacy_file} 时出错: {e}")
                    success = False
        
        return success
    
    def show_test_summary(self, test_files):
        """显示测试摘要"""
        print("\n" + "="*60)
        print("📊 测试摘要")
        print("="*60)
        
        # 按类型分组
        unit_tests = [f for f in test_files if 'unit' in str(f)]
        integration_tests = [f for f in test_files if 'integration' in str(f)]
        performance_tests = [f for f in test_files if 'performance' in str(f)]
        
        print(f"单元测试: {len(unit_tests)} 个文件")
        for test in unit_tests:
            print(f"  - {test.name}")
        
        print(f"集成测试: {len(integration_tests)} 个文件")
        for test in integration_tests:
            print(f"  - {test.name}")
        
        print(f"性能测试: {len(performance_tests)} 个文件")
        for test in performance_tests:
            print(f"  - {test.name}")
        
        total_tests = len(test_files)
        print(f"\n总计: {total_tests} 个测试文件")
    
    def main(self):
        """主函数"""
        parser = argparse.ArgumentParser(description="测试运行器")
        parser.add_argument("--unit", action="store_true", help="仅运行单元测试")
        parser.add_argument("--integration", action="store_true", help="仅运行集成测试")
        parser.add_argument("--performance", action="store_true", help="仅运行性能测试")
        parser.add_argument("--file", type=str, help="运行特定的测试文件")
        parser.add_argument("--coverage", action="store_true", help="显示测试覆盖率")
        parser.add_argument("--verbose", "-v", action="store_true", help="详细输出")
        parser.add_argument("--legacy", action="store_true", help="同时运行遗留测试")
        parser.add_argument("--all", action="store_true", help="运行所有测试（包括遗留）")
        
        args = parser.parse_args()
        
        print("🧪 文件加密解密工具 - 测试运行器")
        print("="*60)
        
        # 确定测试类型
        test_type = None
        if args.unit:
            test_type = "unit"
        elif args.integration:
            test_type = "integration"
        elif args.performance:
            test_type = "performance"
        
        # 发现测试文件
        test_files = self.discover_tests(test_type, args.file)
        
        if not test_files:
            print("❌ 没有找到测试文件")
            return 1
        
        # 显示测试摘要
        self.show_test_summary(test_files)
        
        print("\n" + "="*60)
        print("开始运行测试...")
        print("="*60)
        
        # 运行新架构的测试 - 使用 unittest 模式
        success = self.run_tests_with_unittest(test_files, args.verbose)
        
        # 如果需要，运行遗留测试
        if args.legacy or args.all:
            legacy_success = self.run_legacy_tests()
            success = success and legacy_success
        
        print("\n" + "="*60)
        if success:
            print("🎉 所有测试通过！")
            return 0
        else:
            print("⚠️  部分测试失败")
            return 1


if __name__ == "__main__":
    runner = TestRunner()
    exit(runner.main())