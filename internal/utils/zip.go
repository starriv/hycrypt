package utils

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// zipDirectory 将目录压缩为 zip 文件
func ZipDirectory(sourceDir, zipFilePath string) error {
	// 创建 zip 文件
	zipFile, err := os.Create(zipFilePath)
	if err != nil {
		return fmt.Errorf("创建 zip 文件失败: %w", err)
	}
	defer zipFile.Close()

	// 创建 zip writer
	zipWriter := zip.NewWriter(zipFile)
	defer zipWriter.Close()

	// 遍历目录并添加文件到 zip
	return filepath.WalkDir(sourceDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("遍历目录时出错: %w", err)
		}

		// 跳过目录本身
		if d.IsDir() {
			return nil
		}

		// 计算相对路径
		relPath, err := filepath.Rel(sourceDir, path)
		if err != nil {
			return fmt.Errorf("计算相对路径失败: %w", err)
		}

		// 在 zip 中创建文件
		zipFileWriter, err := zipWriter.Create(relPath)
		if err != nil {
			return fmt.Errorf("在 zip 中创建文件失败: %w", err)
		}

		// 打开源文件
		sourceFile, err := os.Open(path)
		if err != nil {
			return fmt.Errorf("打开源文件失败: %w", err)
		}
		defer sourceFile.Close()

		// 复制文件内容到 zip
		_, err = io.Copy(zipFileWriter, sourceFile)
		if err != nil {
			return fmt.Errorf("复制文件到 zip 失败: %w", err)
		}

		return nil
	})
}

// unzipFile 解压 zip 文件到指定目录
func UnzipFile(zipFilePath, destDir string) error {
	// 打开 zip 文件
	zipReader, err := zip.OpenReader(zipFilePath)
	if err != nil {
		return fmt.Errorf("打开 zip 文件失败: %w", err)
	}
	defer zipReader.Close()

	// 确保目标目录存在
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("创建目标目录失败: %w", err)
	}

	// 解压所有文件
	for _, file := range zipReader.File {
		// 构造目标文件路径
		destPath := filepath.Join(destDir, file.Name)

		// 确保目标文件的目录存在
		if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
			return fmt.Errorf("创建文件目录失败: %w", err)
		}

		// 打开 zip 中的文件
		zipFile, err := file.Open()
		if err != nil {
			return fmt.Errorf("打开 zip 中的文件失败: %w", err)
		}
		defer zipFile.Close()

		// 创建目标文件
		destFile, err := os.Create(destPath)
		if err != nil {
			return fmt.Errorf("创建目标文件失败: %w", err)
		}
		defer destFile.Close()

		// 复制文件内容
		_, err = io.Copy(destFile, zipFile)
		if err != nil {
			return fmt.Errorf("复制文件内容失败: %w", err)
		}
	}

	return nil
}

// isDirectory 检查路径是否为目录
func IsDirectory(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

// createTempZipFile 为目录创建临时 zip 文件
func CreateTempZipFile(dirPath string) (string, error) {
	// 获取目录名
	dirName := filepath.Base(dirPath)

	// 创建临时 zip 文件
	tempDir := os.TempDir()
	timestamp := fmt.Sprintf("%d", os.Getpid())
	tempZipPath := filepath.Join(tempDir, fmt.Sprintf("crypto-zip-%s-%s.zip", dirName, timestamp))

	// 压缩目录
	if err := ZipDirectory(dirPath, tempZipPath); err != nil {
		return "", fmt.Errorf("压缩目录失败: %w", err)
	}

	return tempZipPath, nil
}
