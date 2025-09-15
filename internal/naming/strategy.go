package naming

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"regexp"
	"strings"
	"time"
)

// DefaultStrategyInterface 默认文件命名策略
type DefaultStrategyInterface struct {
	dateFormat string
	extension  string
}

func DefaultStrategy(extension string) *DefaultStrategyInterface {
	return &DefaultStrategyInterface{
		dateFormat: "20060102",
		extension:  extension,
	}
}

func (s *DefaultStrategyInterface) GenerateEncryptedName(originalName, method string) string {
	now := time.Now()
	dateStr := now.Format(s.dateFormat)

	// 生成6位随机hash前缀
	hashPrefix := s.generateRandomHash(6)

	// 检查是否是临时文件（文本输入）
	if s.isTemporaryFile(originalName) {
		randomStr := s.generateRandomString(8)
		return fmt.Sprintf("%s-%s-%s-%s%s", randomStr, hashPrefix, dateStr, method, s.extension)
	}

	// 保留完整的原始文件名（包括所有扩展名）
	return fmt.Sprintf("%s-%s-%s-%s%s", originalName, hashPrefix, dateStr, method, s.extension)
}

func (s *DefaultStrategyInterface) ParseEncryptedName(encryptedName string) (originalName, method, date string, isDirectory bool) {
	// 移除加密扩展名
	if !strings.HasSuffix(encryptedName, s.extension) {
		return encryptedName, "", "", false
	}

	nameWithoutExt := strings.TrimSuffix(encryptedName, s.extension)

	// 检查是否是目录压缩包（.zip.encrypted格式）
	if strings.HasSuffix(encryptedName, ".zip"+s.extension) {
		isDirectory = true
		// 移除 .zip.encrypted，只保留核心名称用于解析
		nameWithoutExt = strings.TrimSuffix(encryptedName, ".zip"+s.extension)
	}

	// 解析格式：name-hash-date-method
	// 使用非贪婪匹配，从后往前匹配最后的 hash-date-method 部分
	pattern := `^(.+)-([a-z0-9]{6})-(\d{8})-(rsa|kmac)$`
	re := regexp.MustCompile(pattern)
	matches := re.FindStringSubmatch(nameWithoutExt)

	if len(matches) == 5 {
		originalName = matches[1]
		// hash = matches[2] // 暂时不需要返回hash
		date = matches[3]
		method = matches[4]

		// 如果是随机生成的文件名（8位字母数字），替换为友好名称
		if len(originalName) == 8 && s.isAllAlphaNum(originalName) {
			originalName = "text-content.txt"
		}
	} else {
		// 解析失败，返回原名称
		originalName = nameWithoutExt
	}

	return originalName, method, date, isDirectory
}

func (s *DefaultStrategyInterface) IsEncryptedFile(fileName string) bool {
	if !strings.HasSuffix(fileName, s.extension) {
		return false
	}

	// 检查是否包含加密算法标识
	nameWithoutExt := strings.TrimSuffix(fileName, s.extension)
	return strings.Contains(nameWithoutExt, "-rsa-") ||
		strings.Contains(nameWithoutExt, "-kmac-") ||
		// 兼容旧格式
		strings.Contains(fileName, ".rsa.") ||
		strings.Contains(fileName, ".kmac.")
}

// 辅助方法
func (s *DefaultStrategyInterface) isTemporaryFile(filename string) bool {
	return strings.Contains(filename, "crypto-text-") || strings.Contains(filename, ".tmp")
}

func (s *DefaultStrategyInterface) generateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	result := make([]byte, length)
	for i := range result {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		result[i] = charset[num.Int64()]
	}
	return string(result)
}

// generateRandomHash 生成指定长度的随机hash（仅使用小写字母和数字）
func (s *DefaultStrategyInterface) generateRandomHash(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	result := make([]byte, length)
	for i := range result {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		result[i] = charset[num.Int64()]
	}
	return string(result)
}

func (s *DefaultStrategyInterface) isAllAlphaNum(str string) bool {
	for _, r := range str {
		if !((r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')) {
			return false
		}
	}
	return true
}

// DirectoryStrategy 目录命名策略
type DirectoryStrategy struct {
	*DefaultStrategyInterface
}

func CreateDirectoryStrategy(extension string) *DirectoryStrategy {
	return &DirectoryStrategy{
		DefaultStrategyInterface: DefaultStrategy(extension),
	}
}

func (d *DirectoryStrategy) GenerateEncryptedName(originalName, method string) string {
	now := time.Now()
	dateStr := now.Format(d.dateFormat)

	// 生成6位随机hash前缀
	hashPrefix := d.generateRandomHash(6)

	// 目录加密后使用 .zip.encrypted 格式
	return fmt.Sprintf("%s-%s-%s-%s.zip%s", originalName, hashPrefix, dateStr, method, d.extension)
}
