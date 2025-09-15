package utils

import (
	"fmt"
	"strings"

	"hycrypt/internal/constants"
)

// GetOriginalFileName 从加密文件名恢复原始文件名
// 处理加密时添加的模式和重复文件时的随机后缀
func GetOriginalFileName(encryptedName string) string {
	// 处理 .hycrypt 扩展名的文件名恢复逻辑
	if strings.HasSuffix(encryptedName, ".hycrypt") {
		base := encryptedName[:len(encryptedName)-len(".hycrypt")]
		parts := strings.Split(base, "-")

		// 检查是否有重复文件后缀（6位随机字符串）
		// 格式可能是: name-hash-date-algorithm-random6.hycrypt 或 name-hash-date-algorithm.ext-random6.hycrypt
		lastPart := parts[len(parts)-1]
		hasDuplicateSuffix := len(lastPart) == 6 && IsAlphaNumeric(lastPart)

		if hasDuplicateSuffix && len(parts) >= 5 {
			// 有重复后缀，格式: name-hash-date-algorithm-random6.hycrypt
			// 移除最后4个部分：hash-date-algorithm-random6
			return strings.Join(parts[:len(parts)-4], "-")
		} else if len(parts) >= 4 {
			// 标准格式: name-hash-date-algorithm.hycrypt
			// 移除最后3个部分：hash-date-algorithm
			return strings.Join(parts[:len(parts)-3], "-")
		}
	}

	// 兼容旧的 .encrypted 格式
	if strings.HasSuffix(encryptedName, ".encrypted") {
		nameWithoutExt := strings.TrimSuffix(encryptedName, ".encrypted")
		parts := strings.Split(nameWithoutExt, "-")
		if len(parts) >= 3 {
			// 文件格式：filename-date-algorithm
			algorithm := parts[len(parts)-1]
			if algorithm == constants.AlgorithmRSA || algorithm == constants.AlgorithmKMAC {
				datePart := parts[len(parts)-2]
				if len(datePart) == 8 && isAllDigits(datePart) {
					originalParts := parts[:len(parts)-2]
					if len(originalParts) > 0 {
						originalName := strings.Join(originalParts, "-")
						// 如果原文件名是8位随机字符串，返回友好名称
						if len(originalParts) == 1 && len(originalParts[0]) == 8 && IsAlphaNumeric(originalParts[0]) {
							return "text-content.txt"
						}
						return originalName
					}
				}
			}
		}
	}

	return encryptedName
}

// IsAlphaNumeric 检查字符串是否只包含字母和数字（用于验证6位随机后缀）
func IsAlphaNumeric(s string) bool {
	for _, r := range s {
		if !((r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')) {
			return false
		}
	}
	return true
}

// isAllDigits 检查字符串是否只包含数字
func isAllDigits(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// FormatFileSize 格式化文件大小显示
func FormatFileSize(size int64) string {
	const unit = 1024
	if size < unit {
		return fmt.Sprintf("%d B", size)
	}
	div, exp := int64(unit), 0
	for n := size / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(size)/float64(div), "KMGTPE"[exp])
}
