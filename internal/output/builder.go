package output

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

// ErrorResult 创建错误结果
func ErrorResult(err error) *OperationResult {
	return &OperationResult{
		Success: false,
		Type:    TypeError,
		Error:   err,
		Message: err.Error(),
	}
}

// ErrorResultWithMessage 创建带消息的错误结果
func ErrorResultWithMessage(message string) *OperationResult {
	return &OperationResult{
		Success: false,
		Type:    TypeError,
		Message: message,
	}
}

// SmartEncryptionResult 智能加密结果构建
func SmartEncryptionResult(inputPath, outputPath, algorithm string, fileSize int64, processTime time.Duration) *OperationResult {
	fileName := filepath.Base(inputPath)

	// 判断是否为临时文件（文本输入）
	if strings.Contains(inputPath, "crypto-text-") || strings.Contains(inputPath, ".tmp") {
		fileName = "文本内容"
	}

	// 构造实际生成的加密文件名
	encryptedFileName := generateEncryptedFileName(fileName, algorithm)

	return &OperationResult{
		Success:     true,
		Type:        TypeEncryption,
		Message:     "加密完成",
		ProcessTime: processTime,
		Details: &ResultDetails{
			FileName:   encryptedFileName,
			FilePath:   inputPath,
			FileSize:   fileSize,
			Algorithm:  strings.ToUpper(algorithm),
			OutputPath: outputPath,
			Extra:      make(map[string]interface{}),
		},
	}
}

// SmartDecryptionResult 智能解密结果构建
func SmartDecryptionResult(inputPath, outputPath, detectedAlgorithm string, fileSize int64, processTime time.Duration) *OperationResult {
	fileName := filepath.Base(inputPath)

	return &OperationResult{
		Success:     true,
		Type:        TypeDecryption,
		Message:     "解密完成",
		ProcessTime: processTime,
		Details: &ResultDetails{
			FileName:   fileName,
			FilePath:   inputPath,
			FileSize:   fileSize,
			Algorithm:  detectedAlgorithm + " 解密",
			OutputPath: outputPath,
			Extra:      make(map[string]interface{}),
		},
	}
}

// generateEncryptedFileName 生成加密文件名
func generateEncryptedFileName(originalName, algorithm string) string {
	now := time.Now()
	dateStr := now.Format("20060102")

	// 检查是否是临时文件（文本输入）
	if strings.Contains(originalName, "crypto-text-") || strings.Contains(originalName, ".tmp") {
		return fmt.Sprintf("随机文件名-%s-%s.hycrypt", dateStr, algorithm)
	}

	// 对于普通文件，保留完整文件名（包括所有扩展名）
	return fmt.Sprintf("%s-%s-%s.hycrypt", originalName, dateStr, algorithm)
}
