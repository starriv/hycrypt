package interactivecli

import (
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"hycrypt/internal/constants"
)

// DecryptProcessor 解密处理器
type DecryptProcessor struct{}

// NewDecryptProcessor 创建解密处理器
func NewDecryptProcessor() *DecryptProcessor {
	return &DecryptProcessor{}
}

// ProcessDecryption 处理解密操作
func (p *DecryptProcessor) ProcessDecryption(m Model) operationResult {
	startTime := time.Now()

	// 处理文本解密
	if m.inputType == "text" {
		return p.processTextDecryption(m, startTime)
	}

	cryptoService, err := CryptoService(m.config)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("初始化加密服务失败: %v", err))
	}

	outputDir := p.resolveOutputDirectory(m)

	var targetPath string
	var originalFileSize int64

	targetPath = strings.TrimSpace(m.pathInput.Value())
	if info, err := os.Stat(targetPath); err == nil {
		originalFileSize = info.Size()
	}

	// 使用已检测到的算法，如果没有则尝试从路径检测
	detectedAlgorithm := strings.ToUpper(m.algorithm)
	if detectedAlgorithm == "" {
		// 回退到路径检测
		if strings.Contains(targetPath, "-rsa"+m.config.Encryption.FileExtension) {
			detectedAlgorithm = constants.AlgorithmRSA
			m.config.Encryption.Method = constants.AlgorithmRSA
		} else if strings.Contains(targetPath, "-kmac"+m.config.Encryption.FileExtension) {
			detectedAlgorithm = constants.AlgorithmKMAC
			m.config.Encryption.Method = constants.AlgorithmKMAC
		} else {
			detectedAlgorithm = "未知"
		}
	} else {
		// 确保配置中的方法与检测到的算法一致
		m.config.Encryption.Method = m.algorithm
	}

	// 重新创建加密服务以使用正确的算法
	cryptoService, err = CryptoService(m.config)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("重新初始化加密服务失败: %v", err))
	}

	actualOutputPath, err := cryptoService.DecryptPath(targetPath, outputDir)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("解密失败: %v", err))
	}

	// 从实际输出路径获取文件名（包含可能的重复后缀）
	actualDecryptedFile := filepath.Base(actualOutputPath)

	resultInfo := EncryptionResult{
		FileName:       filepath.Base(targetPath), // 保持原始加密文件名用于显示
		FileSize:       originalFileSize,
		Algorithm:      detectedAlgorithm + " 解密",
		EncryptionTime: time.Since(startTime).String(),
		OutputPath:     outputDir,
		DecryptedFile:  actualDecryptedFile, // 新增字段存储实际解密后的文件名
	}

	return newOperationResultWithInfo(true, "解密完成", resultInfo)
}

// resolveOutputDirectory 解析输出目录
func (p *DecryptProcessor) resolveOutputDirectory(m Model) string {
	outputDir := m.outputInput.Value()
	if outputDir == "" {
		// 用户未指定目录，根据隐私输出设置决定输出位置
		if m.config.Output.PrivateOutput {
			// 隐私输出开启：使用全局配置目录
			outputDir = m.config.GetDecryptedDirPath()
		} else {
			// 隐私输出关闭：使用输入文件同目录
			inputPath := strings.TrimSpace(m.pathInput.Value())
			if inputPath != "" {
				outputDir = filepath.Dir(inputPath)
			} else {
				// 如果没有输入路径，回退到配置目录
				outputDir = m.config.GetDecryptedDirPath()
			}
		}
	} else {
		// 用户指定了目录，处理相对路径
		if !filepath.IsAbs(outputDir) {
			// 相对路径基于程序运行目录
			cwd, err := os.Getwd()
			if err == nil {
				if outputDir == "./" || outputDir == "." {
					// 特殊处理："./" 表示在当前目录下使用配置的目录名
					configDirName := m.config.Directories.DecryptedDir
					outputDir = filepath.Join(cwd, configDirName)
				} else {
					outputDir = filepath.Join(cwd, outputDir)
				}
			}
		}
	}
	return outputDir
}

// processTextDecryption 处理文本解密
func (p *DecryptProcessor) processTextDecryption(m Model, startTime time.Time) operationResult {
	textContent := m.textArea.Value()

	if strings.TrimSpace(textContent) == "" {
		return newOperationResult(false, "输入为空")
	}

	// 使用统一的清理函数检查输入是否为十六进制格式
	cleanedText := cleanHexInput(textContent)

	// 如果输入看起来像十六进制，尝试十六进制解密
	if len(cleanedText)%2 == 0 && isHexString(cleanedText) {
		// 更新配置中的算法为用户选择的算法
		originalMethod := m.config.Encryption.Method
		m.config.Encryption.Method = m.algorithm
		defer func() {
			m.config.Encryption.Method = originalMethod
		}()
		return p.processHexDecryptionFromText(m, startTime, cleanedText)
	}

	// 否则直接解密文本内容
	return p.processDirectTextDecryption(m, startTime, textContent)
}

// processHexDecryptionFromText 从文本输入处理十六进制解密 - 现在直接输出到终端
func (p *DecryptProcessor) processHexDecryptionFromText(m Model, startTime time.Time, hexStr string) operationResult {
	// 将十六进制字符串转换为字节数组
	encryptedData, err := hex.DecodeString(hexStr)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("解析十六进制字符串失败: %v", err))
	}

	// 注意：这里不需要再次更新算法，因为调用者已经设置了
	// 创建加密服务
	cryptoService, err := CryptoService(m.config)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("初始化加密服务失败: %v", err))
	}

	// 直接解密数据
	var decryptedData []byte

	// 根据不同的加密方法进行解密
	switch m.config.Encryption.Method {
	case constants.AlgorithmRSA:
		decryptedData, err = decryptDataWithRSA(cryptoService, encryptedData)
	case constants.AlgorithmKMAC:
		decryptedData, err = decryptDataWithKMAC(cryptoService, encryptedData)
	default:
		return newOperationResult(false, fmt.Sprintf("不支持的加密方法: %s", m.config.Encryption.Method))
	}

	if err != nil {
		return newOperationResult(false, fmt.Sprintf("解密失败: %v", err))
	}

	// 计算处理时间
	processingTime := time.Since(startTime)

	// 返回触发十六进制输出的特殊结果
	return operationResult{
		success: true,
		message: "HEX_OUTPUT_TRIGGER",
		resultInfo: EncryptionResult{
			FileName:       "HEX_OUTPUT",
			FileSize:       0,
			Algorithm:      strings.ToUpper(m.config.Encryption.Method) + " 解密",
			EncryptionTime: processingTime.String(),
			OutputPath:     fmt.Sprintf("%s|%s|%s", string(decryptedData), hexStr, strings.ToUpper(m.config.Encryption.Method)+" 解密"),
		},
	}
}

// processDirectTextDecryption 直接解密文本内容（非十六进制）
func (p *DecryptProcessor) processDirectTextDecryption(m Model, startTime time.Time, textContent string) operationResult {
	// 这个功能主要用于解密从其他来源获得的加密文本
	// 目前我们主要支持十六进制解密，所以这里返回提示
	return newOperationResult(false, "文本解密需要输入十六进制格式的加密数据")
}

// isHexString 检查字符串是否为有效的十六进制字符串
func isHexString(s string) bool {
	for _, r := range s {
		if !((r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F')) {
			return false
		}
	}
	return true
}
